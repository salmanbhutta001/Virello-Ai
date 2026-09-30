"""Admin withdrawals + earnings rules (wallet admin endpoints).

Covers the Admin Panel Withdrawals tab contracts:
- GET /api/v1/admin/withdrawals (pending first, user_email included)
- POST /{id}/approve {admin_note?} -> approved, note saved, audit-logged
- POST /{id}/reject {reason} -> rejected, cash refunded, audit-logged
- POST /{id}/mark-paid {payment_ref} -> paid, audit-logged
- GET/PUT /api/v1/admin/earnings/rules
Guards: require_admin (403 otherwise), invalid transitions rejected.
"""
from __future__ import annotations

import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.config import settings
from app.core.security import create_token
from app.main import app
from app.models.core import AuditLog, User
from app.models.notifications import UserNotification  # noqa: F401 — register table for init_db
from app.models.wallet import CashLedger, Withdrawal


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


async def _mk_user(is_admin: bool = False) -> str:
    async with SessionLocal() as db:
        u = User(
            email=f"wd_{uuid.uuid4().hex[:8]}@test.com",
            name="Withdrawal Tester",
            preferred_language="en",
            is_admin=is_admin,
        )
        db.add(u)
        await db.commit()
        await db.refresh(u)
        return str(u.id)


@pytest_asyncio.fixture
async def admin_uid(monkeypatch):
    uid = await _mk_user(is_admin=True)
    async with SessionLocal() as db:
        email = (await db.execute(
            select(User.email).where(
                User.id == uuid.UUID(uid)))).scalar_one()
    # Admin panel is email-allowlisted (Hafiz 2026-09-30): admit the fixture
    # admin for the duration of the test.
    monkeypatch.setattr(settings, "admin_emails", email)
    return uid


@pytest_asyncio.fixture
async def user_uid():
    return await _mk_user(is_admin=False)


def _auth(uid: str) -> dict:
    token = create_token(uid, timedelta(minutes=30), "access")
    return {"Authorization": f"Bearer {token}"}


async def _mk_withdrawal(user_uid: str, cents: int = 1500) -> str:
    async with SessionLocal() as db:
        w = Withdrawal(
            user_id=uuid.UUID(user_uid),
            amount_cents=cents,
            method_id="bank_transfer",
            method_details={"bank_name": "Test Bank",
                            "account_title": "Tester",
                            "iban": "PK00TEST0000000000000001"},
            status="pending",
            age_confirmed=True,
        )
        db.add(w)
        await db.commit()
        await db.refresh(w)
        return str(w.id)


async def _audit_count(action: str) -> int:
    async with SessionLocal() as db:
        rows = (await db.execute(
            select(AuditLog).where(AuditLog.action == action))).all()
        return len(rows)


# ---------------------------------------------------------------- list
@pytest.mark.asyncio
async def test_withdrawals_list_pending_first(client, admin_uid, user_uid):
    wid1 = await _mk_withdrawal(user_uid, 1500)
    wid2 = await _mk_withdrawal(user_uid, 2500)
    # one already-decided row must sort after pending ones
    async with SessionLocal() as db:
        w = (await db.execute(
            select(Withdrawal).where(Withdrawal.id == uuid.UUID(wid2)))).scalar_one()
        w.status = "paid"
        await db.commit()
    r = await client.get("/api/v1/admin/withdrawals", headers=_auth(admin_uid))
    assert r.status_code == 200
    items = r.json()["withdrawals"]
    ids = [i["id"] for i in items]
    assert wid1 in ids and wid2 in ids
    # pending first
    first_pending = next(i for i in items if i["status"] == "pending")
    last_paid = next(i for i in items if i["id"] == wid2)
    assert ids.index(first_pending["id"]) < ids.index(last_paid["id"])
    row = next(i for i in items if i["id"] == wid1)
    assert row["user_email"].endswith("@test.com")
    assert row["amount_cents"] == 1500
    assert row["method_details"]["iban"] == "PK00TEST0000000000000001"
    assert row["age_confirmed"] is True

    r = await client.get("/api/v1/admin/withdrawals?status=pending",
                         headers=_auth(admin_uid))
    assert all(i["status"] == "pending" for i in r.json()["withdrawals"])


@pytest.mark.asyncio
async def test_withdrawals_require_admin(client, user_uid):
    r = await client.get("/api/v1/admin/withdrawals", headers=_auth(user_uid))
    assert r.status_code == 403


# ---------------------------------------------------------------- approve
@pytest.mark.asyncio
async def test_withdrawal_approve_with_note(client, admin_uid, user_uid):
    wid = await _mk_withdrawal(user_uid)
    before = await _audit_count("admin.withdrawal.approve")
    r = await client.post(f"/api/v1/admin/withdrawals/{wid}/approve",
                          json={"admin_note": "looks good"},
                          headers=_auth(admin_uid))
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert body["withdrawal"]["status"] == "approved"
    assert body["withdrawal"]["admin_note"] == "looks good"
    assert await _audit_count("admin.withdrawal.approve") == before + 1

    # second approve is an invalid transition
    r = await client.post(f"/api/v1/admin/withdrawals/{wid}/approve",
                          json={}, headers=_auth(admin_uid))
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_withdrawal_approve_no_body_ok(client, admin_uid, user_uid):
    wid = await _mk_withdrawal(user_uid)
    r = await client.post(f"/api/v1/admin/withdrawals/{wid}/approve",
                          headers=_auth(admin_uid))
    assert r.status_code == 200
    assert r.json()["withdrawal"]["status"] == "approved"


# ---------------------------------------------------------------- reject
@pytest.mark.asyncio
async def test_withdrawal_reject_refunds_cash(client, admin_uid, user_uid):
    wid = await _mk_withdrawal(user_uid, 2000)
    before = await _audit_count("admin.withdrawal.reject")
    r = await client.post(f"/api/v1/admin/withdrawals/{wid}/reject",
                          json={"reason": "suspicious"},
                          headers=_auth(admin_uid))
    assert r.status_code == 200
    assert r.json()["withdrawal"]["status"] == "rejected"
    assert r.json()["withdrawal"]["admin_note"] == "suspicious"
    assert await _audit_count("admin.withdrawal.reject") == before + 1
    async with SessionLocal() as db:
        refund = (await db.execute(select(CashLedger).where(
            CashLedger.user_id == uuid.UUID(user_uid),
            CashLedger.reason == "withdrawal_refund"))).scalars().all()
        assert any(x.delta_cents == 2000 for x in refund)


# ---------------------------------------------------------------- mark paid
@pytest.mark.asyncio
async def test_withdrawal_mark_paid(client, admin_uid, user_uid):
    wid = await _mk_withdrawal(user_uid)
    await client.post(f"/api/v1/admin/withdrawals/{wid}/approve",
                      json={}, headers=_auth(admin_uid))
    before = await _audit_count("admin.withdrawal.mark_paid")
    r = await client.post(f"/api/v1/admin/withdrawals/{wid}/mark-paid",
                          json={"payment_ref": "TX-123"},
                          headers=_auth(admin_uid))
    assert r.status_code == 200
    assert r.json()["withdrawal"]["status"] == "paid"
    assert r.json()["withdrawal"]["payment_ref"] == "TX-123"
    assert await _audit_count("admin.withdrawal.mark_paid") == before + 1

    # cannot mark a pending withdrawal paid
    wid2 = await _mk_withdrawal(user_uid)
    r = await client.post(f"/api/v1/admin/withdrawals/{wid2}/mark-paid",
                          json={"payment_ref": "TX-999"},
                          headers=_auth(admin_uid))
    assert r.status_code == 422


# ---------------------------------------------------------------- rules
@pytest.mark.asyncio
async def test_earnings_rules_get_put(client, admin_uid, user_uid):
    r = await client.get("/api/v1/admin/earnings/rules",
                         headers=_auth(admin_uid))
    assert r.status_code == 200
    rules = r.json()["rules"]
    assert rules["share_cents"] == 5
    assert rules["share_click_cents"] == 3

    r = await client.get("/api/v1/admin/earnings/rules",
                         headers=_auth(user_uid))
    assert r.status_code == 403

    orig = rules["share_cents"]
    try:
        r = await client.put("/api/v1/admin/earnings/rules",
                             json={"share_cents": 9},
                             headers=_auth(admin_uid))
        assert r.status_code == 200
        assert r.json()["rules"]["share_cents"] == 9
        r = await client.get("/api/v1/admin/earnings/rules",
                             headers=_auth(admin_uid))
        assert r.json()["rules"]["share_cents"] == 9
    finally:
        await client.put("/api/v1/admin/earnings/rules",
                         json={"share_cents": orig},
                         headers=_auth(admin_uid))
