"""Virello Points: balance, history, rules, leaderboard, redemption,
share-to-earn."""
from __future__ import annotations

import hashlib
import importlib
import logging
import re
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.security import decode_token
from app.models.commerce import Product
from app.models.core import User
from app.models.rewards import PointsLedger, ShareClick
from app.services import rewards as rewards_svc
from app.services import reward_claims as claims_svc
from app.services import wallet as wallet_svc
from app.services.affiliate.amazon import AmazonAffiliateProvider

router = APIRouter()
share_redirect_router = APIRouter()
log = logging.getLogger(__name__)

_ASIN_RE = re.compile(r"^[A-Z0-9]{10}$")


@router.get("/balance")
async def balance(user: User = Depends(get_current_user),
                 db: AsyncSession = Depends(get_db)) -> dict:
    return await rewards_svc.get_balance(db, user.id)


@router.get("/history")
async def history(limit: int = 30, offset: int = 0,
                  user: User = Depends(get_current_user),
                  db: AsyncSession = Depends(get_db)) -> dict:
    limit = max(1, min(limit, 100))
    offset = max(0, offset)
    rows = (await db.execute(
        select(PointsLedger)
        .where(PointsLedger.user_id == user.id,
               PointsLedger.delta != 0)  # cap_skipped rows are audit-only
        .order_by(desc(PointsLedger.created_at))
        .limit(limit).offset(offset))).scalars().all()
    return {"history": [
        {"delta": r.delta, "reason": r.reason,
         "created_at": r.created_at.isoformat() if r.created_at else None}
        for r in rows]}


@router.get("/rules")
async def rules(db: AsyncSession = Depends(get_db)) -> dict:
    return {"rules": rewards_svc.RULES,
            "levels": [{"name": n, "min_points": m}
                       for n, m in rewards_svc.LEVELS],
            "level_discounts": rewards_svc.LEVEL_DISCOUNTS,
            "creator_bonus_points": rewards_svc.CREATOR_BONUS_POINTS,
            "default_post_reward_cents":
                await claims_svc.get_default_post_reward_cents(db),
            "auto_approve": await claims_svc.get_auto_approve(db)}


@router.get("/leaderboard")
async def leaderboard(period: str = "rolling", limit: int = 20,
                      db: AsyncSession = Depends(get_db)) -> dict:
    """Top earners. period=rolling (last 7d) | week (current contest week)
    | month (current contest month)."""
    try:
        return await rewards_svc.leaderboard(db, limit, period)
    except ValueError as exc:
        raise HTTPException(400, str(exc))


@router.get("/winners")
async def winners(limit: int = 30,
                  db: AsyncSession = Depends(get_db)) -> dict:
    """Recent contest winners (weekly/monthly), newest first."""
    return {"winners": await rewards_svc.get_winners(db, limit)}


class RedeemIn(BaseModel):
    points: int


@router.post("/redeem")
async def redeem(body: RedeemIn,
                 user: User = Depends(get_current_user),
                 db: AsyncSession = Depends(get_db)) -> dict:
    try:
        return await rewards_svc.redeem(db, user.id, int(body.points))
    except ValueError as exc:
        raise HTTPException(400, str(exc))


# ------------------------------------------------- proof-based claims
# Hafiz's pivot: share rewards are PROOF-BASED. Share button -> system
# share -> upload a screenshot of the shared post -> admin approves ->
# cash is credited. The old auto-credit path is REMOVED (410 below).
class ClaimIn(BaseModel):
    claim_type: str
    post_id: str | None = None   # placement id (share claims)
    ref_id: str | None = None    # alias for post_id
    proof_url: str | None = None  # from POST /uploads/proof (REQUIRED for share)


@router.post("/claim")
async def create_claim(body: ClaimIn,
                       user: User = Depends(get_current_user),
                       db: AsyncSession = Depends(get_db)) -> dict:
    """File a reward claim. share claims need a screenshot proof and wait
    for admin approval; auto-approve types credit instantly."""
    try:
        claim = await claims_svc.file_claim(
            db, user.id, body.claim_type,
            ref_id=body.post_id or body.ref_id,
            proof_url=body.proof_url)
    except claims_svc.ClaimError as exc:
        raise HTTPException(exc.status, exc.code)
    out = claims_svc.claim_to_dict(claim)
    out["message"] = (
        "Under review — an admin will check your screenshot soon."
        if claim.status == "pending" else "Approved and credited.")
    return out


@router.get("/claims")
async def my_claims(limit: int = 30, offset: int = 0,
                    user: User = Depends(get_current_user),
                    db: AsyncSession = Depends(get_db)) -> dict:
    """My claims: pending / approved / rejected, with admin notes."""
    limit = max(1, min(limit, 100))
    offset = max(0, offset)
    rows = await claims_svc.my_claims(db, user.id, limit, offset)
    return {"claims": [claims_svc.claim_to_dict(c) for c in rows]}


@router.post("/share")
async def share_completed() -> dict:
    """REMOVED: share rewards are now proof-based (file a claim).
    Kept as a route so old clients get guidance instead of a bare 404 —
    NO cash is paid here anymore."""
    raise HTTPException(status_code=410, detail={
        "error": "share_rewards_are_claim_based",
        "message": ("Share rewards now need a screenshot proof and admin "
                    "approval. Upload your screenshot, then file a claim."),
        "claim_endpoint": "/api/v1/rewards/claim",
        "proof_upload_endpoint": "/api/v1/uploads/proof",
    })


# ------------------------------------------------------------ share-to-earn
# Story line: "Post karo -> points. Share karo, bikwao -> cash."
# Share rewards pay CASH (integer cents) — the points ledger is never
# touched by share actions.
async def _catalog_asin_ok(db: AsyncSession, asin: str) -> bool:
    provider = AmazonAffiliateProvider()
    row = (await db.execute(select(Product.id).where(
        Product.affiliate_url == provider.build_affiliate_url(asin),
        Product.is_active.is_(True)))).scalar_one_or_none()
    return row is not None


async def _first_tagged_asin(db: AsyncSession, post_id: str) -> str | None:
    """Best-effort: first tagged ASIN of a shoppable post."""
    try:
        puuid = uuid.UUID(str(post_id))
    except (ValueError, AttributeError):
        return None
    for mod in ("app.models.shop", "app.models.commerce"):
        try:
            pp = getattr(importlib.import_module(mod), "PostProduct", None)
        except ImportError:
            continue
        if pp is None:
            continue
        row = (await db.execute(select(pp.asin).where(
            pp.post_id == puuid).limit(1))).scalar_one_or_none()
        if row:
            return str(row).upper()
    return None


class ShareLinkIn(BaseModel):
    asin: str | None = None
    post_id: str | None = None


@router.post("/share-link")
async def share_link(body: ShareLinkIn,
                    user: User = Depends(get_current_user),
                    db: AsyncSession = Depends(get_db)) -> dict:
    """Per-user share link for an affiliate product. Signed, non-guessable."""
    asin = (body.asin or "").strip().upper() or None
    if not asin and body.post_id:
        asin = await _first_tagged_asin(db, body.post_id)
    if not asin or not _ASIN_RE.match(asin):
        raise HTTPException(
            400, "asin (10 characters) or a post with tagged products required")
    if not await _catalog_asin_ok(db, asin):
        raise HTTPException(404, "Product not in the Virello catalog")
    code = wallet_svc.make_share_code(user.id, asin)
    return {"share_url": wallet_svc.share_url_for(code),
            "code": code, "asin": asin}


@router.get("/share-stats")
async def share_stats(user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)) -> dict:
    return await wallet_svc.get_share_stats(db, user.id)


@router.get("/volume-progress")
async def volume_progress(user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)) -> dict:
    """Volume-bonus progress: verified share-clicks in rolling 7 days (points)."""
    return await rewards_svc.get_volume_progress_points(db, user.id)


@router.get("/sellers")
async def seller_leaderboard(period: str = "week",
                             user: User = Depends(get_current_user),
                             db: AsyncSession = Depends(get_db)) -> dict:
    """Top Sellers leaderboard: ranked by VERIFIED share-link clicks.
    Separate from the posters leaderboard. Prizes in POINTS (no cash)."""
    data = await wallet_svc.get_seller_leaderboard(db, period)
    # Convert cash prize display to points (500 pts = $1.00).
    if "prize_cents" in data:
        cents = int(data["prize_cents"] or 0)
        points = (cents * 500) // 100
        data["prize_points"] = points
        data.pop("prize_cents", None)
        data.pop("prize_display", None)
    return data


@router.get("/seller-winners")
async def seller_winners(user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)) -> dict:
    return {"winners": await wallet_svc.get_seller_winners(db)}


@router.get("/payouts")
async def payout_wall(limit: int = 20, offset: int = 0,
                      db: AsyncSession = Depends(get_db)) -> dict:
    """Points-only system: no cash payouts. Returns empty.
    (Kept for API compatibility; mobile no longer shows this.)"""
    return {"payouts": [], "total": 0}


@share_redirect_router.get("/s/{code}")
async def follow_share_link(code: str, request: Request,
                            db: AsyncSession = Depends(get_db)):
    """Public share-link landing: verify, log the visit, pay the sharer
    cash per verified click, then hand off to /shop/go (affiliate tag +
    unified click logging live there). Tampered codes 404."""
    verified = wallet_svc.verify_share_code(code)
    if verified is None:
        raise HTTPException(404, "Invalid share link")
    sharer_id, asin = verified

    # Optional viewer identity: a valid Bearer token identifies the viewer
    # (self-clicks earn nothing); anonymous browsers fall back to IP hash.
    viewer_id: uuid.UUID | None = None
    auth = request.headers.get("authorization", "")
    if auth.lower().startswith("bearer "):
        try:
            viewer_id = uuid.UUID(decode_token(auth[7:].strip()))
        except (ValueError, AttributeError):
            viewer_id = None
    ip = request.client.host if request.client else "unknown"
    ip_hash = hashlib.sha256(ip.encode()).hexdigest()

    db.add(ShareClick(code=code, sharer_user_id=sharer_id, asin=asin,
                      viewer_user_id=viewer_id, viewer_ip_hash=ip_hash))
    await db.commit()
    viewer_key = f"user:{viewer_id}" if viewer_id else f"ip:{ip_hash}"
    try:
        await rewards_svc.award_share_click_points(db, sharer_id, viewer_key,
                                                   viewer_id, asin, code)
    except Exception:
        log.exception("rewards: share_click points award failed")
    return RedirectResponse(f"/api/v1/shop/go/{asin}", status_code=302)
