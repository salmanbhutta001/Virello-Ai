"""Shoppable posts: affiliate click-through + click tracking.

GET /shop/go/{asin} is PUBLIC. The server builds the affiliate URL
(server-side Partner Tag); the client never supplies a tag. Every tap is
logged to ShopClick and, when the post owner can be resolved, pays the
owner +3 cents cash via wallet.award_product_click_cash (50/day cap,
no self-clicks, dedupe by clicker+asin+day). Reward failures never
break the redirect.
"""
from __future__ import annotations

import hashlib
import logging
import re
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_token
from app.models.commerce import Product, ShopClick
from app.models.core import Campaign, User
from app.models.growth import DiscoveryPlacement
from app.routers.admin import require_admin
from app.services.affiliate.amazon import AmazonAffiliateProvider

log = logging.getLogger(__name__)
router = APIRouter()

_ASIN_RE = re.compile(r"^[A-Z0-9]{10}$")
_ASIN_IN_URL = re.compile(r"/dp/([A-Z0-9]{10})")


def _asin_of_url(url: str | None) -> str | None:
    m = _ASIN_IN_URL.search(url or "")
    return m.group(1) if m else None


async def _catalog_product(db: AsyncSession, asin: str) -> Product | None:
    url = AmazonAffiliateProvider().build_affiliate_url(asin)
    return (await db.execute(select(Product).where(
        Product.affiliate_url == url,
        Product.is_active.is_(True)))).scalar_one_or_none()


def _optional_user_id(request: Request) -> uuid.UUID | None:
    """Valid Bearer <redacted> -> user uuid, else None. Never raises."""
    try:
        auth = request.headers.get("authorization")
        if not auth:
            return None
        scheme, _, token = auth.partition(" ")
        if scheme.lower() != "bearer" or not token.strip():
            return None
        return uuid.UUID(decode_token(token.strip()))
    except Exception:
        return None


@router.get("/shop/go/{asin}")
async def shop_go(asin: str, request: Request,
                  db: AsyncSession = Depends(get_db)):
    """Outbound click on a tagged product. Public; logs the click, rewards
    the post owner when resolvable, then 302s to the server-built
    Amazon affiliate URL."""
    asin = (asin or "").strip().upper()
    if not _ASIN_RE.match(asin):
        raise HTTPException(404, "Unknown product")
    if await _catalog_product(db, asin) is None:
        raise HTTPException(404, "Unknown product")

    clicker_uid = _optional_user_id(request)
    if clicker_uid is not None:
        # Only count signed tokens for real users — forged/unknown subs
        # fall back to anonymous IP attribution.
        known = (await db.execute(
            select(User.id).where(User.id == clicker_uid))).scalar_one_or_none()
        if known is None:
            clicker_uid = None

    post_id = None
    raw_post = request.query_params.get("post")
    if raw_post:
        try:
            post_id = uuid.UUID(raw_post)
        except ValueError:
            post_id = None

    client_host = request.client.host if request.client else "unknown"
    ip_hash = hashlib.sha256(client_host.encode()).hexdigest()

    click = ShopClick(asin=asin, post_id=post_id,
                      user_id=clicker_uid, ip_hash=ip_hash)
    db.add(click)
    await db.commit()
    await db.refresh(click)

    # Resolve the post owner for the +3c cash click reward.
    try:
        owner_id = None
        if post_id is not None:
            placement = (await db.execute(select(DiscoveryPlacement).where(
                DiscoveryPlacement.id == post_id))).scalar_one_or_none()
            if placement is not None:
                campaign = (await db.execute(select(Campaign).where(
                    Campaign.id == placement.campaign_id))).scalar_one_or_none()
                if campaign is not None:
                    owner_id = campaign.user_id
        if owner_id is not None:
            from app.services import wallet as wallet_svc
            await wallet_svc.award_product_click_cash(
                db, owner_id, clicker_uid, asin)
    except Exception:
        log.exception("wallet: product_click hook failed")

    target = AmazonAffiliateProvider().build_affiliate_url(asin)
    return RedirectResponse(url=target, status_code=302)


@router.get("/admin/shop/clicks")
async def shop_clicks(db: AsyncSession = Depends(get_db),
                      admin: User = Depends(require_admin)) -> dict:
    """Click report: per-ASIN totals and top posts by clicks. Admin only."""
    asin_rows = (await db.execute(
        select(ShopClick.asin, func.count().label("c"))
        .group_by(ShopClick.asin)
        .order_by(desc("c")).limit(50))).all()

    provider = AmazonAffiliateProvider()
    urls = [provider.build_affiliate_url(a) for a, _ in asin_rows]
    title_by_asin: dict[str, str] = {}
    if urls:
        for p in (await db.execute(select(Product).where(
                Product.affiliate_url.in_(urls)))).scalars().all():
            asin = _asin_of_url(p.affiliate_url)
            if asin:
                title_by_asin[asin] = p.title
    per_asin = [{"asin": a, "title": title_by_asin.get(a, ""),
                 "clicks": c} for a, c in asin_rows]

    post_rows = (await db.execute(
        select(ShopClick.post_id, func.count().label("c"))
        .where(ShopClick.post_id.is_not(None))
        .group_by(ShopClick.post_id)
        .order_by(desc("c")).limit(50))).all()
    post_ids = [pid for pid, _ in post_rows]
    info: dict[uuid.UUID, dict] = {}
    if post_ids:
        placements = (await db.execute(select(DiscoveryPlacement).where(
            DiscoveryPlacement.id.in_(post_ids)))).scalars().all()
        cids = {pl.campaign_id for pl in placements}
        campaigns = (await db.execute(select(Campaign).where(
            Campaign.id.in_(cids)))).scalars().all() if cids else []
        camp_by_id = {c.id: c for c in campaigns}
        uids = {c.user_id for c in campaigns}
        users = (await db.execute(select(User).where(
            User.id.in_(uids)))).scalars().all() if uids else []
        user_by_id = {u.id: u for u in users}
        for pl in placements:
            c = camp_by_id.get(pl.campaign_id)
            owner = user_by_id.get(c.user_id) if c else None
            info[pl.id] = {
                "campaign_title": c.title if c else "",
                "owner": (owner.name or owner.email) if owner else "",
            }
    top_posts = [{"post_id": str(pid),
                  "campaign_title": info.get(pid, {}).get("campaign_title", ""),
                  "owner": info.get(pid, {}).get("owner", ""),
                  "clicks": c} for pid, c in post_rows]
    return {"per_asin": per_asin, "top_posts": top_posts}
