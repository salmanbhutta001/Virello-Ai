"""Money + credit bookkeeping. Idempotent, auditable.

Flow (billing router):
  1. create order via provider -> store pending Transaction (idempotency_key).
  2. verify server-side (or verified webhook) -> record_transaction COMPLETED.
  3. grant_purchase: subscription -> activate_subscription; credits -> grant_credits.
  4. refund -> provider.refund + mark Transaction refunded + reverse credits.

Every credit movement appends to credit_ledger with a running balance.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.billing import CreditLedger, Transaction
from app.models.core import Plan, Subscription, User
from .base import Money, Verification

CREDIT_PACKS = {
    "starter": {"credits": 1_000, "price_usd": Decimal("9")},
    "growth": {"credits": 5_000, "price_usd": Decimal("39")},
    "scale": {"credits": 20_000, "price_usd": Decimal("129")},
}


async def record_transaction(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    provider: str,
    provider_ref: str,
    kind: str,
    money: Money,
    status: str,
    idempotency_key: str,
    raw: dict | None = None,
) -> Transaction:
    """Insert a transaction; on duplicate (provider, provider_ref) or
    idempotency_key return the existing row — never double-record."""
    txn = Transaction(
        user_id=user_id, provider=provider, provider_ref=provider_ref,
        kind=kind, amount=money.amount, currency=money.currency,
        status=status, idempotency_key=idempotency_key, raw=raw or {},
    )
    db.add(txn)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        existing = (await db.execute(
            select(Transaction).where(Transaction.provider_ref == provider_ref)
        )).scalar_one()
        return existing
    await db.refresh(txn)
    return txn


async def grant_credits(db: AsyncSession, user_id: uuid.UUID, credits: int,
                        reason: str, transaction_id: uuid.UUID | None = None) -> int:
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one()
    user.credits = (user.credits or 0) + credits
    db.add(CreditLedger(user_id=user_id, delta=credits,
                        balance_after=user.credits, reason=reason,
                        transaction_id=transaction_id))
    await db.commit()
    return user.credits


async def spend_credits(db: AsyncSession, user_id: uuid.UUID, credits: int,
                        reason: str) -> int:
    """Deduct AI credits; raises ValueError when the balance is insufficient."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one()
    if (user.credits or 0) < credits:
        raise ValueError("insufficient AI credits")
    return await grant_credits(db, user_id, -credits, reason)


async def activate_subscription(db: AsyncSession, user_id: uuid.UUID, plan_slug: str,
                                provider: str, provider_ref: str,
                                transaction_id: uuid.UUID) -> Subscription:
    plan = Plan[plan_slug] if plan_slug in Plan.__members__ else Plan.pro
    sub = (await db.execute(
        select(Subscription).where(Subscription.user_id == user_id))).scalar_one_or_none()
    now = datetime.now(timezone.utc)
    if sub is None:
        sub = Subscription(user_id=user_id)
        db.add(sub)
    sub.plan = plan
    sub.status = "active"
    sub.provider = provider
    sub.provider_ref = provider_ref
    sub.current_period_end = now + timedelta(days=30)
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one()
    user.plan = plan
    await db.commit()
    await db.refresh(sub)
    return sub


async def apply_verified_purchase(db: AsyncSession, txn: Transaction,
                                  verification: Verification,
                                  plan_slug: str = "",
                                  credit_pack: str = "") -> dict:
    """Turn a server-verified payment into subscription/credits. Safe to call
    twice: a transaction already marked completed is a no-op."""
    if txn.status == "completed":
        return {"already_applied": True, "transaction_id": str(txn.id)}
    if verification.status != "completed":
        txn.status = "failed"
        await db.commit()
        raise ValueError("payment not completed at provider")
    if verification.money.amount != txn.amount or \
            verification.money.currency != txn.currency:
        txn.status = "failed"
        await db.commit()
        raise ValueError("amount mismatch — possible tampering")
    txn.status = "completed"
    txn.provider_ref = verification.provider_ref
    txn.raw = {**(txn.raw or {}), "verification": verification.raw}
    await db.commit()

    result: dict = {"transaction_id": str(txn.id)}
    if txn.kind == "subscription" and plan_slug:
        sub = await activate_subscription(db, txn.user_id, plan_slug,
                                          txn.provider, verification.provider_ref,
                                          txn.id)
        result["subscription"] = {"plan": sub.plan.value,
                                  "current_period_end": sub.current_period_end.isoformat()}
    elif txn.kind == "credits" and credit_pack in CREDIT_PACKS:
        pack = CREDIT_PACKS[credit_pack]
        balance = await grant_credits(db, txn.user_id, pack["credits"],
                                      f"credit_pack:{credit_pack}", txn.id)
        result["credits_balance"] = balance
    return result
