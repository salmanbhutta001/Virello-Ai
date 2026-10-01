"""Billing: PayPal / Payoneer / Google Pay — provider-abstracted.

Rules:
  - The client never decides money moved. Only server-side verification
    (provider API lookup or signature-verified webhook) completes a purchase.
  - Every money movement is recorded in `transactions` (idempotent);
    every credit movement in `credit_ledger`.
  - Plans are DB-driven (Admin Dashboard can edit pricing).
"""
from __future__ import annotations

import uuid
import json
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user
from app.core.database import get_db
from app.models.billing import CreditLedger, PlanConfig, Transaction
from app.models.core import Subscription, User
from app.services.payments import (
    Money, OrderRequest, PaymentProviderError, PaymentProviderNotConfigured,
    get_payment_provider, supported_providers,
)
from app.services.payments.ledger import (
    CREDIT_PACKS, apply_verified_purchase, record_transaction,
)
from app.services.email import send_payment_receipt

router = APIRouter()

DEFAULT_PLANS = [
    {"slug": "free", "name": "Free", "price_usd": Decimal("0"),
     "ai_credits_monthly": 300, "campaigns_limit": 3, "sort": 0},
    {"slug": "pro", "name": "Pro", "price_usd": Decimal("19"),
     "ai_credits_monthly": 5000, "campaigns_limit": 25, "sort": 1},
    {"slug": "scale", "name": "Scale", "price_usd": Decimal("49"),
     "ai_credits_monthly": 20000, "campaigns_limit": 100, "sort": 2},
]


async def _plans(db: AsyncSession) -> list[PlanConfig]:
    rows = (await db.execute(select(PlanConfig).order_by(PlanConfig.sort))).scalars().all()
    if not rows:
        for p in DEFAULT_PLANS:
            db.add(PlanConfig(**p, currency=settings.billing_currency))
        await db.commit()
        rows = (await db.execute(select(PlanConfig).order_by(PlanConfig.sort))).scalars().all()
    return list(rows)


def _plan_dict(p: PlanConfig) -> dict:
    return {"slug": p.slug, "name": p.name, "price": float(p.price_usd),
            "currency": p.currency, "ai_credits_monthly": p.ai_credits_monthly,
            "campaigns_limit": p.campaigns_limit, "active": p.active}


class OrderIn(BaseModel):
    provider: str                      # paypal | payoneer | google_pay
    kind: str                          # subscription | credits
    plan_slug: str = ""
    credit_pack: str = ""
    return_url: str = ""
    cancel_url: str = ""
    idempotency_key: str = ""


class VerifyIn(BaseModel):
    provider: str
    provider_ref: str                  # order id / token from the client
    transaction_id: str = ""
    plan_slug: str = ""
    credit_pack: str = ""


@router.get("/providers")
async def providers() -> dict:
    return {"providers": supported_providers()}


@router.get("/plans")
async def plans(db: AsyncSession = Depends(get_db)) -> dict:
    return {"plans": [_plan_dict(p) for p in await _plans(db) if p.active]}


@router.get("/credit-packs")
async def credit_packs() -> dict:
    return {"packs": {k: {"credits": v["credits"], "price_usd": float(v["price_usd"])}
                      for k, v in CREDIT_PACKS.items()},
            "currency": settings.billing_currency}


@router.post("/orders")
async def create_order(body: OrderIn, db: AsyncSession = Depends(get_db),
                       user: User = Depends(get_current_user)) -> dict:
    if body.provider not in supported_providers():
        raise HTTPException(400, f"Unsupported provider: {body.provider}")
    if body.kind == "subscription":
        plan = next((p for p in await _plans(db)
                     if p.slug == body.plan_slug and p.active), None)
        if not plan:
            raise HTTPException(400, "Unknown plan")
        money = Money(Decimal(str(plan.price_usd)), plan.currency)
    elif body.kind == "credits":
        pack = CREDIT_PACKS.get(body.credit_pack)
        if not pack:
            raise HTTPException(400, "Unknown credit pack")
        money = Money(pack["price_usd"], settings.billing_currency)
    else:
        raise HTTPException(400, "kind must be subscription|credits")

    provider = get_payment_provider(body.provider)
    idem = body.idempotency_key or f"{user.id}-{body.kind}-{body.plan_slug or body.credit_pack}"
    try:
        order = await provider.create_order(OrderRequest(
            user_id=str(user.id), kind=body.kind, money=money,
            plan_slug=body.plan_slug, credit_pack=body.credit_pack,
            return_url=body.return_url, cancel_url=body.cancel_url,
            idempotency_key=idem))
    except PaymentProviderNotConfigured as exc:
        raise HTTPException(503, str(exc))
    except PaymentProviderError as exc:
        raise HTTPException(502, str(exc))
    finally:
        await provider.aclose()

    txn = await record_transaction(
        db, user_id=user.id, provider=provider.name,
        provider_ref=order.provider_order_id, kind=body.kind,
        money=money, status="pending", idempotency_key=idem,
        raw={"plan_slug": body.plan_slug, "credit_pack": body.credit_pack})
    return {"transaction_id": str(txn.id),
            "provider": order.provider,
            "provider_order_id": order.provider_order_id,
            "approval_url": order.approval_url,
            "client_payload": order.client_payload}


@router.post("/verify")
async def verify_payment(body: VerifyIn, db: AsyncSession = Depends(get_db),
                         user: User = Depends(get_current_user)) -> dict:
    """Client hands back the provider reference; the SERVER asks the provider
    whether money actually moved. Never trust the client."""
    provider = get_payment_provider(body.provider)
    try:
        verification = await provider.verify(body.provider_ref)
    except PaymentProviderNotConfigured as exc:
        raise HTTPException(503, str(exc))
    except PaymentProviderError as exc:
        raise HTTPException(502, str(exc))
    finally:
        await provider.aclose()

    if body.transaction_id:
        txn = (await db.execute(select(Transaction).where(
            Transaction.id == uuid.UUID(body.transaction_id),
            Transaction.user_id == user.id))).scalar_one_or_none()
        if not txn:
            raise HTTPException(404, "Transaction not found")
    else:
        txn = (await db.execute(select(Transaction).where(
            Transaction.provider_ref == body.provider_ref,
            Transaction.user_id == user.id))).scalar_one_or_none()
        if not txn:
            raise HTTPException(404, "Transaction not found")

    plan_slug = body.plan_slug or (txn.raw or {}).get("plan_slug", "")
    credit_pack = body.credit_pack or (txn.raw or {}).get("credit_pack", "")
    try:
        result = await apply_verified_purchase(db, txn, verification,
                                               plan_slug=plan_slug,
                                               credit_pack=credit_pack)
    except ValueError as exc:
        raise HTTPException(402, str(exc))
    # Greeting + payment receipt email. Never breaks the purchase:
    # send_payment_receipt catches all exceptions and returns False.
    await db.refresh(txn)
    if not result.get("already_applied"):
        item_name = await _receipt_item_name(db, plan_slug, credit_pack)
        await send_payment_receipt(user, txn, item_name)
    return {"ok": True, **result}


async def _receipt_item_name(db: AsyncSession, plan_slug: str,
                             credit_pack: str) -> str:
    """Human-friendly purchased-item label for the receipt email."""
    if plan_slug:
        row = (await db.execute(
            select(PlanConfig).where(PlanConfig.slug == plan_slug)
        )).scalar_one_or_none()
        if row:
            return f"{row.name} Plan"
    if credit_pack and credit_pack in CREDIT_PACKS:
        return f"{CREDIT_PACKS[credit_pack]['credits']:,} AI Credits"
    return "Virello Purchase"


@router.post("/webhooks/{provider_name}")
async def webhook(provider_name: str, request: Request,
                  db: AsyncSession = Depends(get_db)) -> dict:
    """Signature-verified, idempotent webhook intake."""
    if provider_name not in supported_providers():
        raise HTTPException(404, "Unknown provider")
    provider = get_payment_provider(provider_name)
    body = await request.body()
    try:
        event = await provider.parse_webhook(dict(request.headers), body)
    except PaymentProviderError as exc:
        raise HTTPException(400, str(exc))
    finally:
        await provider.aclose()
    if not event.verified:
        raise HTTPException(400, "Unverified webhook")

    txn = (await db.execute(select(Transaction).where(
        Transaction.provider_ref == event.provider_ref))).scalar_one_or_none()
    if not txn:
        # Unknown reference: record it for admin review, change nothing.
        return {"received": True, "matched": False}
    if event.event_type.endswith(("completed", "approved", "paid")):
        verification = await provider.verify(event.provider_ref)
        await provider.aclose()
        plan_slug = (txn.raw or {}).get("plan_slug", "")
        credit_pack = (txn.raw or {}).get("credit_pack", "")
        try:
            await apply_verified_purchase(db, txn, verification,
                                          plan_slug=plan_slug, credit_pack=credit_pack)
        except ValueError:
            pass  # amount mismatch etc. -> admin reviews the transaction row
    return {"received": True, "matched": True}


@router.post("/transactions/{transaction_id}/refund")
async def refund(transaction_id: str, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    txn = (await db.execute(select(Transaction).where(
        Transaction.id == uuid.UUID(transaction_id),
        Transaction.user_id == user.id))).scalar_one_or_none()
    if not txn or txn.status != "completed":
        raise HTTPException(404, "Completed transaction not found")
    provider = get_payment_provider(txn.provider)
    try:
        result = await provider.refund(
            txn.provider_ref, Money(txn.amount, txn.currency))
    except PaymentProviderError as exc:
        raise HTTPException(502, str(exc))
    finally:
        await provider.aclose()
    txn.status = "refunded"
    if txn.kind == "credits":
        pack_credits = next((v["credits"] for k, v in CREDIT_PACKS.items()
                             if (txn.raw or {}).get("credit_pack") == k), 0)
        if pack_credits:
            user.credits = max(0, (user.credits or 0) - pack_credits)
            db.add(CreditLedger(user_id=user.id, delta=-pack_credits,
                                balance_after=user.credits,
                                reason=f"refund:{txn.id}", transaction_id=txn.id))
    await db.commit()
    return {"ok": True, "refund_id": result.provider_refund_id,
            "status": result.status}


@router.get("/transactions")
async def my_transactions(db: AsyncSession = Depends(get_db),
                          user: User = Depends(get_current_user)) -> dict:
    rows = (await db.execute(select(Transaction).where(
        Transaction.user_id == user.id).order_by(Transaction.created_at.desc())
    )).scalars().all()
    return {"transactions": [
        {"id": str(t.id), "provider": t.provider, "kind": t.kind,
         "amount": float(t.amount), "currency": t.currency,
         "status": t.status, "created_at": t.created_at.isoformat()} for t in rows]}


@router.get("/credits")
async def my_credits(db: AsyncSession = Depends(get_db),
                     user: User = Depends(get_current_user)) -> dict:
    await db.refresh(user)
    return {"balance": user.credits or 0}


# ---------------- Google Play Billing (in-app purchases) ----------------
from app.services.payments.google_play import (
    PLAY_PRODUCT_IDS, play_token_used, verify_play_token,
)


class PlayVerifyIn(BaseModel):
    product_id: str
    purchase_token: str
    kind: str  # subscription | credits


@router.post("/play/verify")
async def verify_play_purchase(body: PlayVerifyIn,
                               db: AsyncSession = Depends(get_db),
                               user: User = Depends(get_current_user)) -> dict:
    """Verify a Google Play purchase token server-side, then activate.

    The Flutter app calls this after the Play Store purchase completes.
    Money movement and plan/credit activation flow through the shared
    ledger (apply_verified_purchase) — credits/plans are NEVER granted
    locally before this endpoint returns ok.
    """
    expected = PLAY_PRODUCT_IDS.get(body.product_id)
    if not expected:
        raise HTTPException(400, "Unknown Play product id")
    exp_kind, exp_slug = expected
    if body.kind not in ("subscription", "credits") or body.kind != exp_kind:
        raise HTTPException(400, "kind does not match Play product id")
    plan_slug = exp_slug if body.kind == "subscription" else ""
    credit_pack = exp_slug if body.kind == "credits" else ""

    # Money comes from OUR catalog, never from the client.
    if body.kind == "credits":
        pack = CREDIT_PACKS.get(credit_pack)
        if not pack:
            raise HTTPException(400, "Unknown credit pack")
        money = Money(pack["price_usd"], settings.billing_currency)
    else:
        plan = next((p for p in await _plans(db)
                     if p.slug == plan_slug and p.active), None)
        if not plan:
            raise HTTPException(400, "Unknown plan")
        money = Money(Decimal(str(plan.price_usd)), plan.currency)

    # Idempotency: one token = one grant, ever.
    existing = (await db.execute(select(Transaction).where(
        Transaction.provider_ref == body.purchase_token))).scalar_one_or_none()
    if existing is not None:
        if existing.user_id != user.id:
            raise HTTPException(409, "purchase token already used")
        if existing.status == "completed":
            return {"ok": True, "already_applied": True,
                    "transaction_id": str(existing.id)}
        txn = existing
    else:
        txn = None

    play = verify_play_token(body.product_id, body.purchase_token, body.kind)
    if txn is None and play_token_used(play, body.kind):
        # Fresh token that Google already marks consumed/acknowledged
        # and we have no local record: it was used elsewhere.
        raise HTTPException(409, "purchase token already used")

    if txn is None:
        txn = await record_transaction(
            db, user_id=user.id, provider="google_play",
            provider_ref=body.purchase_token, kind=body.kind,
            money=money, status="pending",
            idempotency_key=f"google_play:{body.purchase_token}",
            raw={"product_id": body.product_id, "plan_slug": plan_slug,
                 "credit_pack": credit_pack})

    verification = Verification(
        provider="google_play", provider_ref=body.purchase_token,
        status="completed", money=money,
        payer_id=(play.get("obfuscatedExternalAccountId") or ""),
        raw={"play": play, "product_id": body.product_id})
    try:
        result = await apply_verified_purchase(
            db, txn, verification,
            plan_slug=plan_slug, credit_pack=credit_pack)
    except ValueError as exc:
        raise HTTPException(402, str(exc))
    await db.refresh(txn)
    if not result.get("already_applied"):
        item_name = await _receipt_item_name(db, plan_slug, credit_pack)
        await send_payment_receipt(user, txn, item_name)
    return {"ok": True, **result}


# ---------------- Amazon Appstore IAP (in-app purchases) ----------------
from app.services.payments.amazon_iap import (
    AMAZON_SKUS, verify_amazon_receipt,
)


class AmazonVerifyIn(BaseModel):
    sku: str
    receipt_id: str
    amazon_user_id: str
    kind: str  # subscription | credits


@router.post("/amazon/verify")
async def verify_amazon_purchase(body: AmazonVerifyIn,
                                 db: AsyncSession = Depends(get_db),
                                 user: User = Depends(get_current_user)) -> dict:
    """Verify an Amazon Appstore receipt server-side (RVS), then activate.

    The Flutter app (amazon flavor) calls this after the Amazon purchase
    completes. Money movement and plan/credit activation flow through the
    shared ledger (apply_verified_purchase) — credits/plans are NEVER
    granted locally before this endpoint returns ok. The app only calls
    notifyFulfillment (consumes the Amazon purchase) after this succeeds.
    """
    expected = AMAZON_SKUS.get(body.sku)
    if not expected:
        raise HTTPException(400, "Unknown Amazon SKU")
    exp_kind, exp_slug = expected
    if body.kind not in ("subscription", "credits") or body.kind != exp_kind:
        raise HTTPException(400, "kind does not match Amazon SKU")
    plan_slug = exp_slug if body.kind == "subscription" else ""
    credit_pack = exp_slug if body.kind == "credits" else ""

    # Money comes from OUR catalog, never from the client.
    if body.kind == "credits":
        pack = CREDIT_PACKS.get(credit_pack)
        if not pack:
            raise HTTPException(400, "Unknown credit pack")
        money = Money(pack["price_usd"], settings.billing_currency)
    else:
        plan = next((p for p in await _plans(db)
                     if p.slug == plan_slug and p.active), None)
        if not plan:
            raise HTTPException(400, "Unknown plan")
        money = Money(Decimal(str(plan.price_usd)), plan.currency)

    # Idempotency: one receipt = one grant, ever.
    provider_ref = f"amazon:{body.receipt_id}"
    existing = (await db.execute(select(Transaction).where(
        Transaction.provider_ref == provider_ref))).scalar_one_or_none()
    if existing is not None:
        if existing.user_id != user.id:
            raise HTTPException(409, "receipt already used")
        if existing.status == "completed":
            return {"ok": True, "already_applied": True,
                    "transaction_id": str(existing.id)}
        txn = existing
    else:
        txn = None

    # Amazon RVS check: raises 402/404/502/503 on any problem.
    receipt = verify_amazon_receipt(body.receipt_id, body.amazon_user_id)
    if receipt.get("productId") and receipt["productId"] != body.sku:
        raise HTTPException(400, "receipt SKU mismatch")

    if txn is None:
        txn = await record_transaction(
            db, user_id=user.id, provider="amazon_iap",
            provider_ref=provider_ref, kind=body.kind,
            money=money, status="pending",
            idempotency_key=f"amazon_iap:{body.receipt_id}",
            raw={"sku": body.sku, "plan_slug": plan_slug,
                 "credit_pack": credit_pack,
                 "amazon_user_id": body.amazon_user_id})

    verification = Verification(
        provider="amazon_iap", provider_ref=provider_ref,
        status="completed", money=money,
        payer_id=body.amazon_user_id,
        raw={"amazon_rvs": receipt, "sku": body.sku})
    try:
        result = await apply_verified_purchase(
            db, txn, verification,
            plan_slug=plan_slug, credit_pack=credit_pack)
    except ValueError as exc:
        raise HTTPException(402, str(exc))
    await db.refresh(txn)
    if not result.get("already_applied"):
        item_name = await _receipt_item_name(db, plan_slug, credit_pack)
        await send_payment_receipt(user, txn, item_name)
    return {"ok": True, **result}
