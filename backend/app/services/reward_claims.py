"""Proof-based reward claims: file, auto-approve config, admin decisions.

Hafiz's pivot: share rewards are PROOF-BASED. The user shares a post,
uploads a screenshot of the shared post on their social media, and an
admin approves the claim — only then is cash credited. The old
auto-credit path for share rewards is gone.

Claim types (table supports all; the public /rewards/claim endpoint only
accepts "share" — other types are filed server-side by the event that
earned them, so a user can never self-file an arbitrary amount):

- share: cash, amount = the post's reward badge (per-post reward_cents or
  the default_post_reward_cents setting). proof_url REQUIRED.
- post / streak / like_received / comment_received / volume_bonus /
  winner: auto-approve per the rewards.auto_approve setting — the claim is
  instantly approved and the ledger credited, but still logged as a claim.

Money is integer cents, same as the cash wallet. Points claims credit the
points ledger. Exactly one of amount_cents / points is set per claim.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.billing import SystemSetting
from app.models.core import User
from app.models.growth import DiscoveryPlacement
from app.models.rewards import PointsLedger, RewardClaim
from app.models.wallet import CashLedger
from app.services import wallet as wallet_svc

# ------------------------------------------------------------------ config
DEFAULT_POST_REWARD_CENTS = 5  # Hafiz's default badge: +$0.05
DEFAULT_POST_REWARD_KEY = "rewards.default_post_reward_cents"
AUTO_APPROVE_KEY = "rewards.auto_approve"

# Hafiz's final auto-approve policy: only share waits for a human.
DEFAULT_AUTO_APPROVE: dict[str, bool] = {
    "post": True,
    "streak": True,
    "like_received": True,
    "comment_received": True,
    "share": False,
    "volume_bonus": True,
    "winner": True,
}

CLAIM_TYPES = set(DEFAULT_AUTO_APPROVE)
# claim types a signed-in user may file themselves. Others are filed
# server-side only (the event that earned them passes the amount).
USER_FILEABLE = {"share"}


class ClaimError(Exception):
    """Carries a machine code + HTTP status the router maps to a response."""

    def __init__(self, code: str, status: int = 422):
        self.code = code
        self.status = status
        super().__init__(code)


# ------------------------------------------------------------------ helpers
def fmt_reward(cents: int) -> str:
    """Badge text: +$0.05. Pure integer math, never floats."""
    c = max(0, int(cents))
    return f"+${c // 100}.{c % 100:02d}"


async def _setting_value(db: AsyncSession, key: str):
    row = (await db.execute(
        select(SystemSetting).where(SystemSetting.key == key)
    )).scalar_one_or_none()
    return row.value if row is not None else None


async def get_default_post_reward_cents(db: AsyncSession) -> int:
    """Admin-tunable default badge (settings key
    rewards.default_post_reward_cents); Hafiz's default is 5."""
    try:
        v = int(await _setting_value(db, DEFAULT_POST_REWARD_KEY))
    except (TypeError, ValueError):
        v = DEFAULT_POST_REWARD_CENTS
    return max(0, v)


async def set_default_post_reward_cents(db: AsyncSession, cents: int) -> int:
    cents = max(0, int(cents))
    row = (await db.execute(
        select(SystemSetting).where(SystemSetting.key == DEFAULT_POST_REWARD_KEY)
    )).scalar_one_or_none()
    if row is None:
        db.add(SystemSetting(key=DEFAULT_POST_REWARD_KEY, value=cents))
    else:
        row.value = cents
    await db.commit()
    return cents


async def get_auto_approve(db: AsyncSession) -> dict[str, bool]:
    """Per-type auto-approve policy (settings key rewards.auto_approve),
    merged over Hafiz's defaults — unknown keys are ignored."""
    cfg = dict(DEFAULT_AUTO_APPROVE)
    raw = await _setting_value(db, AUTO_APPROVE_KEY)
    if isinstance(raw, dict):
        for k, v in raw.items():
            if k in cfg:
                cfg[k] = bool(v)
    return cfg


async def effective_post_reward_cents(
        db: AsyncSession, placement: DiscoveryPlacement | None) -> int:
    """The badge amount for a post: its own reward_cents, else the
    admin-tunable default."""
    if placement is not None and placement.reward_cents is not None:
        return max(0, int(placement.reward_cents))
    return await get_default_post_reward_cents(db)


# ------------------------------------------------------------------ filing
async def _placement_or_404(db: AsyncSession, ref_id: str | None):
    try:
        pid = uuid.UUID(str(ref_id))
    except (ValueError, AttributeError, TypeError):
        raise ClaimError("post_not_found", 404)
    placement = (await db.execute(
        select(DiscoveryPlacement).where(DiscoveryPlacement.id == pid)
    )).scalar_one_or_none()
    if placement is None:
        raise ClaimError("post_not_found", 404)
    return placement, str(pid)


async def _credit(db: AsyncSession, claim: RewardClaim) -> None:
    """Credit the ledger for an approved claim. ref_id embeds the claim id,
    so even a duplicate call could never double-pay."""
    if claim.amount_cents:
        db.add(CashLedger(
            user_id=claim.user_id,
            delta_cents=int(claim.amount_cents),
            reason=f"claim_{claim.claim_type}",
            ref_id=f"claim:{claim.id}"))
    elif claim.points:
        db.add(PointsLedger(
            user_id=claim.user_id,
            delta=int(claim.points),
            reason=f"claim_{claim.claim_type}",
            ref_id=str(claim.id)))
    await db.commit()


async def file_claim(db: AsyncSession, user_id: uuid.UUID,
                     claim_type: str, ref_id: str | None = None,
                     amount_cents: int | None = None,
                     points: int | None = None,
                     proof_url: str | None = None,
                     user_fileable_only: bool = True) -> RewardClaim:
    """File a claim. Auto-approve types are instantly approved + credited
    (still logged as a claim). share claims go to the pending queue."""
    claim_type = (claim_type or "").strip().lower()
    if claim_type not in CLAIM_TYPES:
        raise ClaimError("unknown_claim_type", 400)
    if user_fileable_only and claim_type not in USER_FILEABLE:
        # Self-filed claims with self-chosen amounts would be an exploit
        # under auto-approve; other types are filed server-side.
        raise ClaimError("claim_type_not_user_fileable", 400)

    if claim_type == "share":
        if not proof_url:
            raise ClaimError("proof_required", 422)
        if points is not None:
            raise ClaimError("share_pays_cash", 400)
        placement, ref_id = await _placement_or_404(db, ref_id)
        # The badge IS the reward: per-post amount, no exceptions.
        amount_cents = await effective_post_reward_cents(db, placement)
    else:
        if (amount_cents is None) == (points is None):
            raise ClaimError("amount_or_points_required", 400)
        if amount_cents is not None and int(amount_cents) <= 0:
            raise ClaimError("invalid_amount", 400)
        if points is not None and int(points) <= 0:
            raise ClaimError("invalid_amount", 400)

    # Anti-double-claim: one live claim per (user, type, ref). A rejected
    # claim may be re-filed with better proof — it is resubmitted in place
    # (same id; the admin's note stays visible), which keeps the DB unique
    # constraint as the atomic guard against double-filing.
    if ref_id is not None:
        existing = (await db.execute(select(RewardClaim).where(
            RewardClaim.user_id == user_id,
            RewardClaim.claim_type == claim_type,
            RewardClaim.ref_id == ref_id,
        ).order_by(RewardClaim.created_at.desc()))).scalars().first()
        if existing is not None and existing.status != "rejected":
            raise ClaimError("already_claimed", 409)
        if existing is not None:  # rejected -> resubmit in place
            existing.proof_url = proof_url or None
            existing.status = "pending"
            existing.decided_at = None
            if claim_type != "share":
                existing.amount_cents = (int(amount_cents)
                                         if amount_cents is not None else None)
                existing.points = (int(points)
                                   if points is not None else None)
            db.add(existing)
            await db.commit()
            await db.refresh(existing)
            return existing

    claim = RewardClaim(
        user_id=user_id, claim_type=claim_type, ref_id=ref_id,
        amount_cents=int(amount_cents) if amount_cents is not None else None,
        points=int(points) if points is not None else None,
        proof_url=(proof_url or None), status="pending",
    )
    if (await get_auto_approve(db)).get(claim_type, False):
        claim.status = "approved"
        claim.decided_at = datetime.now(timezone.utc)
    db.add(claim)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise ClaimError("already_claimed", 409)
    if claim.status == "approved":
        await _credit(db, claim)
        try:
            await wallet_svc.notify_user(
                db, user_id, "reward_claim",
                "Reward approved",
                _credit_line(claim),
                {"claim_id": str(claim.id)})
        except Exception:
            pass
    await db.refresh(claim)
    return claim


def _credit_line(claim: RewardClaim) -> str:
    if claim.amount_cents:
        return (f"Your {claim.claim_type} reward of "
                f"{wallet_svc.fmt_cents(claim.amount_cents)} was approved.")
    return f"Your {claim.claim_type} reward of {claim.points} pts was approved."


# ------------------------------------------------------------------ deciding
async def decide_claim(db: AsyncSession, claim: RewardClaim, approve: bool,
                       admin_id: uuid.UUID,
                       note: str | None = None) -> RewardClaim:
    """Approve or reject a pending claim. Idempotent: deciding an already
    decided claim returns it unchanged — the ledger is credited at most
    once, ever."""
    if claim.status != "pending":
        return claim
    claim.status = "approved" if approve else "rejected"
    claim.decided_at = datetime.now(timezone.utc)
    if note is not None:
        claim.admin_note = str(note)[:512]
    db.add(claim)
    await db.commit()
    if approve:
        await _credit(db, claim)
    try:
        if approve:
            await wallet_svc.notify_user(
                db, claim.user_id, "reward_claim", "Reward approved",
                _credit_line(claim), {"claim_id": str(claim.id)})
        else:
            await wallet_svc.notify_user(
                db, claim.user_id, "reward_claim", "Reward not approved",
                f"Your {claim.claim_type} claim was not approved."
                + (f" Reason: {claim.admin_note}" if claim.admin_note else "")
                + " You can share again with a clearer screenshot.",
                {"claim_id": str(claim.id)})
    except Exception:
        pass
    # audit the admin action (best effort — never blocks the decision)
    try:
        from app.models.core import AuditLog
        db.add(AuditLog(user_id=admin_id,
                        action=f"admin.claim.{claim.status}",
                        details=str(claim.id)))
        await db.commit()
    except Exception:
        pass
    await db.refresh(claim)
    return claim


# ------------------------------------------------------------------ listing
async def my_claims(db: AsyncSession, user_id: uuid.UUID,
                    limit: int = 30, offset: int = 0) -> list[RewardClaim]:
    rows = (await db.execute(
        select(RewardClaim).where(RewardClaim.user_id == user_id)
        .order_by(RewardClaim.created_at.desc()).limit(limit).offset(offset)
    )).scalars().all()
    return list(rows)


async def admin_list_claims(db: AsyncSession, status: str | None = None,
                            limit: int = 50,
                            offset: int = 0) -> list[RewardClaim]:
    """Admin review queue: pending first, then newest first."""
    stmt = select(RewardClaim)
    if status:
        stmt = stmt.where(RewardClaim.status == status)
    stmt = (stmt.order_by((RewardClaim.status != "pending").asc(),
                          RewardClaim.created_at.desc())
            .limit(limit).offset(offset))
    return list((await db.execute(stmt)).scalars().all())


async def claims_with_context(db: AsyncSession,
                              claims: list[RewardClaim]) -> list[dict]:
    """Enrich claims for the admin queue: user email + post preview."""
    out = []
    if not claims:
        return out
    uids = {c.user_id for c in claims}
    users = (await db.execute(
        select(User).where(User.id.in_(uids)))).scalars().all()
    emails = {u.id: (u.email or "") for u in users}
    # post previews for share claims (ref_id = placement id)
    pids: list[uuid.UUID] = []
    for c in claims:
        if c.claim_type == "share" and c.ref_id:
            try:
                pids.append(uuid.UUID(c.ref_id))
            except (ValueError, AttributeError):
                pass
    previews: dict[str, dict] = {}
    if pids:
        from app.models.core import Campaign
        rows = (await db.execute(
            select(DiscoveryPlacement, Campaign)
            .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
            .where(DiscoveryPlacement.id.in_(pids)))).all()
        for p, camp in rows:
            previews[str(p.id)] = {
                "placement_id": str(p.id),
                "title": camp.title,
                "post_url": camp.post_url,
                "platform": camp.platform,
                "reward_cents": (p.reward_cents
                                 if p.reward_cents is not None else None),
            }
    for c in claims:
        d = claim_to_dict(c)
        d["user_email"] = emails.get(c.user_id, "")
        d["post"] = previews.get(c.ref_id or "")
        out.append(d)
    return out


def claim_to_dict(c: RewardClaim) -> dict:
    return {
        "id": str(c.id),
        "claim_type": c.claim_type,
        "ref_id": c.ref_id,
        "amount_cents": c.amount_cents,
        "amount_display": (wallet_svc.fmt_cents(c.amount_cents)
                           if c.amount_cents else None),
        "points": c.points,
        "proof_url": c.proof_url,
        "status": c.status,
        "admin_note": c.admin_note,
        "created_at": c.created_at.isoformat() if c.created_at else None,
        "decided_at": c.decided_at.isoformat() if c.decided_at else None,
    }
