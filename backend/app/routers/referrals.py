"""Referral loop API — free organic growth strategy #5.

Endpoints (mounted by the coordinator at /api/v1/referrals):
  GET /mine   — the signed-in user's referral code + share link/text
                (auto-generates the code on first call).
  GET /stats  — invites count + referral credits earned (from credit_ledger).

The signup integration lives in app/routers/auth.py via
record_referral_signup() (pending event) and award_referral_credits()
(pay out on verified signup). Both helpers are exported here so auth has a
single import.
"""
from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.billing import CreditLedger
from app.models.core import User
from app.models.referrals import ReferralCode, ReferralEvent
from app.services.payments.ledger import grant_credits

router = APIRouter()

#: AI credits paid to EACH side of a verified referral.
REFERRAL_BONUS_CREDITS = 50
#: Ledger reason tag — stats and admin reports filter on this.
REFERRAL_REASON = "referral_bonus"
#: Public share-link base. Honest and stable; the mobile app appends the code.
SHARE_BASE_URL = "https://virello.app/r"

# Readable alphabet: no 0/O, 1/I/L (avoids copy mistakes).
_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_CODE_LENGTH = 8


def _new_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))


def share_text_for(code: str) -> str:
    return (
        f"Grow on Virello with AI — sign up with my link and we both get "
        f"{REFERRAL_BONUS_CREDITS} free AI credits: {SHARE_BASE_URL}/{code}"
    )


async def get_or_create_code(db: AsyncSession, user_id: uuid.UUID) -> ReferralCode:
    """Return the user's referral code, generating one on first call.

    Retries on the (astronomically unlikely) code collision; the unique
    constraint on referral_codes.code is the final backstop.
    """
    existing = (await db.execute(
        select(ReferralCode).where(ReferralCode.user_id == user_id)
    )).scalar_one_or_none()
    if existing is not None:
        return existing
    for _ in range(5):
        row = ReferralCode(user_id=user_id, code=_new_code())
        db.add(row)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            continue
        await db.refresh(row)
        return row
    # Extremely unlikely: another writer won the race or a collision loop.
    # Fall back to whatever row exists now for this user.
    await db.rollback()
    return (await db.execute(
        select(ReferralCode).where(ReferralCode.user_id == user_id)
    )).scalar_one()


async def record_referral_signup(db: AsyncSession, *,
                                 referral_code: str | None,
                                 new_user: User) -> dict:
    """Record a ``pending`` referral_event for a fresh signup.

    Never raises for bad input: an absent/invalid/self-referral code is
    silently ignored so signup itself always succeeds. Returns a small
    status dict for logging/tests: ok | missing | invalid | self |
    already_referred.

    Never raises for DB problems either (2026-10-08: prod lacked the
    referral tables entirely, which 500'd signup). Referral attribution
    is best-effort; account creation is critical.
    """
    try:
        return await _record_referral_signup_inner(
            db, referral_code=referral_code, new_user=new_user)
    except Exception:
        import logging
        logging.getLogger(__name__).exception(
            "referral: record_referral_signup failed (non-fatal)")
        try:
            await db.rollback()
        except Exception:
            pass
        return {"referral": "error"}


async def _record_referral_signup_inner(db: AsyncSession, *,
                                       referral_code: str | None,
                                       new_user: User) -> dict:
    """Inner implementation of record_referral_signup (may raise)."""
    if not referral_code:
        return {"referral": "missing"}
    normalized = referral_code.strip().upper()
    code_row = (await db.execute(
        select(ReferralCode).where(ReferralCode.code == normalized)
    )).scalar_one_or_none()
    if code_row is None:
        return {"referral": "invalid"}

    # Self-referral: same user id OR same email (case-insensitive) as the
    # code owner. Blocked — no event, no credit, no error to the signer.
    if code_row.user_id == new_user.id:
        return {"referral": "self"}
    owner = (await db.execute(
        select(User.email).where(User.id == code_row.user_id))).scalar_one_or_none()
    new_email = (new_user.email or "").strip().lower()
    if owner and new_email and owner.strip().lower() == new_email:
        return {"referral": "self"}

    # One user can only ever be referred once.
    already = (await db.execute(
        select(ReferralEvent.id).where(
            ReferralEvent.referred_user_id == new_user.id)
    )).scalar_one_or_none()
    if already is not None:
        return {"referral": "already_referred"}

    db.add(ReferralEvent(
        code_id=code_row.id,
        referrer_id=code_row.user_id,
        referred_user_id=new_user.id,
        status="pending",
    ))
    await db.commit()
    return {"referral": "ok"}


async def award_referral_credits(db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Pay the referral bonus once the referred user's signup is VERIFIED.

    Idempotent: the pending -> credited transition is a single conditional
    UPDATE; only the writer that flips the row pays out. Retries and double
    calls can never double-credit.

    Never raises (2026-10-08): the referral tables may be absent on
    databases created before the referral feature (prod 500'd signup
    because of this). Bonus payout is best-effort; signup must succeed.
    """
    try:
        return await _award_referral_credits_inner(db, user_id)
    except Exception:
        import logging
        logging.getLogger(__name__).exception(
            "referral: award_referral_credits failed (non-fatal)")
        try:
            await db.rollback()
        except Exception:
            pass
        return {"awarded": False, "error": "referral-unavailable"}


async def _award_referral_credits_inner(
        db: AsyncSession, user_id: uuid.UUID) -> dict:
    """Inner implementation of award_referral_credits (may raise)."""
    now = datetime.now(timezone.utc)
    result = await db.execute(
        update(ReferralEvent)
        .where(ReferralEvent.referred_user_id == user_id,
               ReferralEvent.status == "pending")
        .values(status="credited", credited_at=now)
    )
    if result.rowcount == 0:
        # No pending event: nothing changed, leave the caller's session
        # untouched (no rollback — that would expire the caller's objects).
        return {"awarded": False}
    await db.commit()

    event = (await db.execute(
        select(ReferralEvent).where(ReferralEvent.referred_user_id == user_id)
    )).scalar_one()
    await grant_credits(db, event.referrer_id, REFERRAL_BONUS_CREDITS,
                        REFERRAL_REASON)
    await grant_credits(db, event.referred_user_id, REFERRAL_BONUS_CREDITS,
                        REFERRAL_REASON)
    # Virello Points for both sides too (+50 each, idempotent per event).
    try:
        from app.services import rewards as rewards_svc
        await rewards_svc.award_referral(db, event.referrer_id, event.id)
        await rewards_svc.award(
            db, event.referred_user_id, rewards_svc.REFERRAL_POINTS,
            "referral", f"{event.id}:referred")
    except Exception:
        import logging
        logging.getLogger(__name__).exception(
            "rewards: referral points hook failed")
    return {"awarded": True, "credits": REFERRAL_BONUS_CREDITS}


# ------------------------------------------------------------ endpoints
@router.get("/mine")
async def my_referral(db: AsyncSession = Depends(get_db),
                      user: User = Depends(get_current_user)) -> dict:
    """My referral code + share link/text. Auto-generates on first call."""
    row = await get_or_create_code(db, user.id)
    link = f"{SHARE_BASE_URL}/{row.code}"
    return {
        "code": row.code,
        "share_url": link,
        "share_text": share_text_for(row.code),
        "bonus_credits": REFERRAL_BONUS_CREDITS,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


@router.get("/stats")
async def referral_stats(db: AsyncSession = Depends(get_db),
                         user: User = Depends(get_current_user)) -> dict:
    """Invites + referral credits earned. Credits come from the ledger
    (single source of truth), never from a counter that could drift."""
    invites = (await db.execute(
        select(func.count()).select_from(ReferralEvent)
        .where(ReferralEvent.referrer_id == user.id)
    )).scalar_one()
    credited = (await db.execute(
        select(func.count()).select_from(ReferralEvent)
        .where(ReferralEvent.referrer_id == user.id,
               ReferralEvent.status == "credited")
    )).scalar_one()
    earned = (await db.execute(
        select(func.coalesce(func.sum(CreditLedger.delta), 0))
        .where(CreditLedger.user_id == user.id,
               CreditLedger.reason == REFERRAL_REASON)
    )).scalar_one()
    return {
        "invites": invites,
        "credited_invites": credited,
        "pending_invites": invites - credited,
        "credits_earned": int(earned or 0),
        "bonus_per_referral": REFERRAL_BONUS_CREDITS,
    }
