"""Cash wallet API: balance, history, withdrawals, points->cash conversion.

Withdrawals are reviewed and paid MANUALLY (bank transfer), usually
within 7 days. Never promise instant.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import AuditLog, User
from app.routers.admin import require_admin
from app.services import wallet as wallet_svc

router = APIRouter()
admin_router = APIRouter()


def _wallet_error(exc: wallet_svc.WalletError) -> HTTPException:
    code = exc.code
    if code.startswith("ineligible:"):
        reasons = code.split(":", 1)[1].split(",")
        return HTTPException(422, {"error": "ineligible",
                                   "reasons": reasons})
    if code.startswith("invalid_method"):
        # e.g. "invalid_method:missing:iban" -> machine + human detail
        detail = code.split(":", 1)[1] if ":" in code else ""
        return HTTPException(422, {"error": "invalid_method",
                                   "detail": detail})
    return HTTPException(422, {"error": code})


@router.get("/balance")
async def balance(user: User = Depends(get_current_user),
                  db: AsyncSession = Depends(get_db)) -> dict:
    cents = await wallet_svc.cash_balance(db, user.id)
    rules = await wallet_svc.get_cash_rules(db)
    per_1000 = rules["points_to_cash_per_1000_cents"]
    return {
        "balance_cents": cents,
        "balance_display": wallet_svc.fmt_cents(cents),
        "conversion": {
            "min_points": rules["min_convert_points"],
            "per_1000_cents": per_1000,
            # e.g. 500 pts = $1.00
            "rate_text": (
                f"{rules['min_convert_points']:,} pts = "
                f"{wallet_svc.fmt_cents(per_1000)}"
            ) if per_1000 else "",
        },
        "withdrawal_note": ("Withdrawals are reviewed and paid manually, "
                            "usually within 7 days."),
    }


@router.get("/history")
async def history(limit: int = 50,
                  user: User = Depends(get_current_user),
                  db: AsyncSession = Depends(get_db)) -> dict:
    return {"history": await wallet_svc.cash_history(
        db, user.id, limit=min(limit, 100))}


@router.get("/methods")
async def methods(user: User = Depends(get_current_user),
                  db: AsyncSession = Depends(get_db)) -> dict:
    """Payout method registry: enabled methods + their field schemas.
    The mobile picker renders its dynamic form from this."""
    return await wallet_svc.get_method_configs(db)


class WithdrawIn(BaseModel):
    amount_cents: int
    method_id: str
    method_details: dict = {}
    age_confirmed: bool = False


@router.post("/withdraw", status_code=201)
async def withdraw(body: WithdrawIn,
                   user: User = Depends(get_current_user),
                   db: AsyncSession = Depends(get_db)) -> dict:
    try:
        w = await wallet_svc.request_withdrawal(
            db, user, body.amount_cents, body.method_id,
            body.method_details, age_confirmed=body.age_confirmed)
    except wallet_svc.WalletError as exc:
        raise _wallet_error(exc)
    return {"ok": True, "withdrawal": wallet_svc._withdrawal_to_dict(w)}


@router.get("/withdrawals")
async def withdrawals(user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)) -> dict:
    return {"withdrawals": await wallet_svc.list_withdrawals(db, user.id)}


class ConvertIn(BaseModel):
    points: int


@router.post("/convert")
async def convert(body: ConvertIn,
                  user: User = Depends(get_current_user),
                  db: AsyncSession = Depends(get_db)) -> dict:
    """Convert points into withdrawable cash. Atomic: both legs or neither."""
    try:
        return {"ok": True,
                **await wallet_svc.convert_points_to_cash(
                    db, user.id, body.points)}
    except wallet_svc.WalletError as exc:
        raise _wallet_error(exc)


# ------------------------------------------------------------ admin
@admin_router.get("/withdrawals")
async def admin_withdrawals(status: str | None = None,
                            admin: User = Depends(require_admin),
                            db: AsyncSession = Depends(get_db)) -> dict:
    """All withdrawals, pending first. Backend only."""
    return {"withdrawals": await wallet_svc.admin_list_withdrawals(
        db, status)}


def _audit(db: AsyncSession, admin: User, action: str, wid: str,
           extra: str = "") -> None:
    db.add(AuditLog(user_id=admin.id, action=action,
                    details=f"withdrawal={wid} {extra}".strip()))


class ApproveIn(BaseModel):
    admin_note: str = ""


@admin_router.post("/withdrawals/{withdrawal_id}/approve")
async def approve(withdrawal_id: str,
                  body: ApproveIn | None = None,
                  admin: User = Depends(require_admin),
                  db: AsyncSession = Depends(get_db)) -> dict:
    try:
        w = await wallet_svc.approve_withdrawal(
            db, uuid.UUID(withdrawal_id),
            (body.admin_note if body else "") or None)
    except wallet_svc.WalletError as exc:
        raise _wallet_error(exc)
    _audit(db, admin, "admin.withdrawal.approve", withdrawal_id,
           f"user={w.user_id} amount={w.amount_cents}")
    await db.commit()
    return {"ok": True, "withdrawal": wallet_svc._withdrawal_to_dict(w)}


class RejectIn(BaseModel):
    reason: str = ""


@admin_router.post("/withdrawals/{withdrawal_id}/reject")
async def reject(withdrawal_id: str, body: RejectIn,
                 admin: User = Depends(require_admin),
                 db: AsyncSession = Depends(get_db)) -> dict:
    try:
        w = await wallet_svc.reject_withdrawal(
            db, uuid.UUID(withdrawal_id), body.reason)
    except wallet_svc.WalletError as exc:
        raise _wallet_error(exc)
    _audit(db, admin, "admin.withdrawal.reject", withdrawal_id,
           f"user={w.user_id} amount={w.amount_cents} note={body.reason}")
    await db.commit()
    return {"ok": True, "withdrawal": wallet_svc._withdrawal_to_dict(w)}


class MarkPaidIn(BaseModel):
    payment_ref: str = ""


@admin_router.post("/withdrawals/{withdrawal_id}/mark-paid")
async def mark_paid(withdrawal_id: str, body: MarkPaidIn,
                    admin: User = Depends(require_admin),
                    db: AsyncSession = Depends(get_db)) -> dict:
    try:
        w = await wallet_svc.mark_withdrawal_paid(
            db, uuid.UUID(withdrawal_id), body.payment_ref)
    except wallet_svc.WalletError as exc:
        raise _wallet_error(exc)
    _audit(db, admin, "admin.withdrawal.mark_paid", withdrawal_id,
           f"user={w.user_id} amount={w.amount_cents} "
           f"payment_ref={body.payment_ref}")
    await db.commit()
    return {"ok": True, "withdrawal": wallet_svc._withdrawal_to_dict(w)}


@admin_router.get("/earnings/rules")
async def get_rules(admin: User = Depends(require_admin),
                    db: AsyncSession = Depends(get_db)) -> dict:
    return {"rules": await wallet_svc.get_cash_rules(db)}


@admin_router.put("/earnings/rules")
async def put_rules(patch: dict,
                    admin: User = Depends(require_admin),
                    db: AsyncSession = Depends(get_db)) -> dict:
    try:
        rules = await wallet_svc.update_cash_rules(db, patch)
    except wallet_svc.WalletError as exc:
        raise _wallet_error(exc)
    db.add(AuditLog(user_id=admin.id, action="admin.earnings.rules.update",
                    details=f"patch_keys={sorted((patch or {}).keys())}"))
    await db.commit()
    return {"ok": True, "rules": rules}


@admin_router.put("/earnings/create-costs")
async def put_create_costs(patch: dict,
                           admin: User = Depends(require_admin),
                           db: AsyncSession = Depends(get_db)) -> dict:
    """Admin tunes per-generation credit costs, e.g. {"video": 25}."""
    from app.services import rewards as rewards_svc
    try:
        costs = await rewards_svc.update_create_costs(db, patch)
    except rewards_svc.GenerationError as exc:
        raise HTTPException(422, {"error": exc.code})
    db.add(AuditLog(user_id=admin.id,
                    action="admin.earnings.create_costs.update",
                    details=f"patch={patch}"))
    await db.commit()
    return {"ok": True, "costs": costs}


@admin_router.put("/earnings/methods")
async def put_methods(toggles: dict,
                      admin: User = Depends(require_admin),
                      db: AsyncSession = Depends(get_db)) -> dict:
    """Admin toggles payout methods: {"paypal": true, "crypto_usdt": false}."""
    configs = None
    for method_id, enabled in (toggles or {}).items():
        try:
            configs = await wallet_svc.set_method_enabled(
                db, str(method_id), bool(enabled))
        except wallet_svc.WalletError as exc:
            raise _wallet_error(exc)
    db.add(AuditLog(user_id=admin.id, action="admin.earnings.methods.update",
                    details=f"toggles={toggles}"))
    await db.commit()
    return {"ok": True,
            "methods": (configs or await wallet_svc.get_method_configs(db)
                        )["methods"]}
