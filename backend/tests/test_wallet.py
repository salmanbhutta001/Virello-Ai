"""Cash wallet: integer-cents math, withdrawals, admin flow, conversion.

Money is ALWAYS integer cents — never floats. Every assertion below
checks exact cent values.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, func, select

from app.core.database import SessionLocal
from app.core.config import settings
from app.core.security import create_token
from app.main import app
from app.models.core import User
from app.models.rewards import PointsLedger, ShareClick
from app.models.wallet import CashLedger, Withdrawal
from app.services import rewards as rewards_svc
from app.services import wallet as wallet_svc


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


def _auth(uid) -> dict:
    return {"Authorization": f"Bearer {create_token(str(uid), timedelta(minutes=30))}"}


def _old_ts(days: int = 8) -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(
        days=days)


async def _mk_user(name="Hafiz Tester", email_verified=True, days_old=8,
                   admin=False) -> uuid.UUID:
    async with SessionLocal() as db:
        u = User(email=f"w_{uuid.uuid4().hex[:8]}@test.com", name=name,
                 preferred_language="en", email_verified=email_verified,
                 created_at=_old_ts(days_old), is_admin=admin)
        db.add(u)
        await db.commit()
        await db.refresh(u)
        return u.id


@pytest_asyncio.fixture
async def user():
    yield await _mk_user()


@pytest_asyncio.fixture
async def eligible_user():
    yield await _mk_user()


@pytest_asyncio.fixture
async def admin_user(monkeypatch):
    uid = await _mk_user(name="Admin", admin=True)
    async with SessionLocal() as db:
        email = (await db.execute(
            select(User.email).where(User.id == uid))).scalar_one()
    # Admin panel is email-allowlisted (Hafiz 2026-09-30): admit the fixture
    # admin for the duration of the test.
    monkeypatch.setattr(settings, "admin_emails", email)
    yield uid


async def _cash(uid) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(CashLedger.delta_cents), 0))
            .where(CashLedger.user_id == uid))).scalar() or 0


async def _points(uid) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(PointsLedger.delta), 0))
            .where(PointsLedger.user_id == uid))).scalar() or 0


async def _grant_cash(uid, cents: int, reason: str = "test_grant") -> None:
    async with SessionLocal() as db:
        db.add(CashLedger(user_id=uid, delta_cents=cents, reason=reason,
                          ref_id=f"t:{uuid.uuid4().hex}"))
        await db.commit()


_BANK_DETAILS = {"bank_name": "Meezan Bank",
                 "account_title": "Hafiz Tester",
                 "iban": "PK36MEZN0001234567890012"}


def _withdraw_body(amount_cents: int, age: bool = True,
                   method_id: str = "bank_transfer",
                   details: dict | None = None) -> dict:
    return {"amount_cents": amount_cents, "method_id": method_id,
            "method_details": details if details is not None
            else dict(_BANK_DETAILS),
            "age_confirmed": age}


# ------------------------------------------------------------ cents math
async def test_fmt_cents_exact():
    assert wallet_svc.fmt_cents(0) == "$0.00"
    assert wallet_svc.fmt_cents(5) == "$0.05"
    assert wallet_svc.fmt_cents(100) == "$1.00"
    assert wallet_svc.fmt_cents(105) == "$1.05"
    assert wallet_svc.fmt_cents(1000) == "$10.00"
    assert wallet_svc.fmt_cents(123456) == "$1234.56"
    assert wallet_svc.fmt_cents(-250) == "-$2.50"


async def test_balance_display_exact(client, eligible_user):
    await _grant_cash(eligible_user, 1005)
    r = await client.get("/api/v1/wallet/balance",
                         headers=_auth(eligible_user))
    assert r.status_code == 200
    data = r.json()
    assert data["balance_cents"] == 1005
    assert data["balance_display"] == "$10.05"
    assert "usually within 7 days" in data["withdrawal_note"]


# ------------------------------------------------------------ withdrawal guards
async def test_withdraw_below_minimum_422(client, eligible_user):
    await _grant_cash(eligible_user, 1500)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(999),
                          headers=_auth(eligible_user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "below_minimum"


async def test_withdraw_age_not_confirmed_422(client, eligible_user):
    await _grant_cash(eligible_user, 1500)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000, age=False),
                          headers=_auth(eligible_user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "age_not_confirmed"


async def test_withdraw_unverified_email_422(client):
    uid = await _mk_user(email_verified=False)
    await _grant_cash(uid, 1500)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000), headers=_auth(uid))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "ineligible"
    assert "email_not_verified" in r.json()["detail"]["reasons"]


async def test_withdraw_account_too_new_422(client):
    uid = await _mk_user(days_old=0)
    await _grant_cash(uid, 1500)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000), headers=_auth(uid))
    assert r.status_code == 422
    assert "account_too_new" in r.json()["detail"]["reasons"]


async def test_withdraw_profile_incomplete_422(client):
    uid = await _mk_user(name="Virello user")
    await _grant_cash(uid, 1500)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000), headers=_auth(uid))
    assert r.status_code == 422
    assert "profile_incomplete" in r.json()["detail"]["reasons"]


async def test_withdraw_insufficient_balance_422(client, eligible_user):
    await _grant_cash(eligible_user, 1200)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1500),
                          headers=_auth(eligible_user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "insufficient_balance"


async def test_withdraw_invalid_method_422(client, eligible_user):
    await _grant_cash(eligible_user, 1500)
    bad = dict(_BANK_DETAILS)
    bad["iban"] = ""
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000, details=bad),
                          headers=_auth(eligible_user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "invalid_method"
    assert "iban" in r.json()["detail"]["detail"]

    # unknown method id
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000, method_id="western_union",
                                              details={}),
                          headers=_auth(eligible_user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "unknown_method"

    # easypaisa with a bad email-free payload is fine; paypal needs email
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(
                              1000, method_id="easypaisa",
                              details={"mobile_number": "03451234567",
                                       "account_title": "Hafiz"}),
                          headers=_auth(eligible_user))
    assert r.status_code == 201, r.text


async def test_withdraw_success_holds_balance(client, eligible_user):
    await _grant_cash(eligible_user, 1200)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000),
                          headers=_auth(eligible_user))
    assert r.status_code == 201, r.text
    w = r.json()["withdrawal"]
    assert w["status"] == "pending"
    assert w["amount_cents"] == 1000
    assert w["amount_display"] == "$10.00"
    assert w["age_confirmed"] is True
    assert w["method_id"] == "bank_transfer"
    assert w["method_details"]["iban"] == _BANK_DETAILS["iban"]
    # Held at request time: spendable balance drops immediately.
    assert await _cash(eligible_user) == 200


async def test_withdraw_double_pending_blocked(client, eligible_user):
    await _grant_cash(eligible_user, 3000)
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000),
                          headers=_auth(eligible_user))
    assert r.status_code == 201
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000),
                          headers=_auth(eligible_user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "pending_exists"


# ------------------------------------------------------------ admin flow
async def _request_withdrawal(uid, cents=1000) -> uuid.UUID:
    async with SessionLocal() as db:
        user = (await db.execute(
            select(User).where(User.id == uid))).scalar_one()
        w = await wallet_svc.request_withdrawal(
            db, user, cents, "bank_transfer", dict(_BANK_DETAILS),
            age_confirmed=True)
        return w.id


async def test_admin_approve_then_mark_paid(client, eligible_user,
                                           admin_user):
    await _grant_cash(eligible_user, 1200)
    wid = await _request_withdrawal(eligible_user)
    r = await client.post(
        f"/api/v1/admin/withdrawals/{wid}/approve",
        headers=_auth(admin_user))
    assert r.status_code == 200
    assert r.json()["withdrawal"]["status"] == "approved"

    r = await client.post(
        f"/api/v1/admin/withdrawals/{wid}/mark-paid",
        json={"payment_ref": "BANK-REF-001"},
        headers=_auth(admin_user))
    assert r.status_code == 200
    w = r.json()["withdrawal"]
    assert w["status"] == "paid"
    assert w["payment_ref"] == "BANK-REF-001"
    # Paid out: the held debit stands, no extra movement.
    assert await _cash(eligible_user) == 200  # 1200 granted - 1000 held


async def test_admin_reject_refunds(client, eligible_user, admin_user):
    await _grant_cash(eligible_user, 1200)
    wid = await _request_withdrawal(eligible_user)
    assert await _cash(eligible_user) == 200
    r = await client.post(
        f"/api/v1/admin/withdrawals/{wid}/reject",
        json={"reason": "iban mismatch"},
        headers=_auth(admin_user))
    assert r.status_code == 200
    w = r.json()["withdrawal"]
    assert w["status"] == "rejected"
    assert w["admin_note"] == "iban mismatch"
    assert await _cash(eligible_user) == 1200  # held amount refunded


async def test_admin_invalid_transition_422(client, eligible_user,
                                           admin_user):
    await _grant_cash(eligible_user, 1200)
    wid = await _request_withdrawal(eligible_user)
    r = await client.post(
        f"/api/v1/admin/withdrawals/{wid}/approve",
        headers=_auth(admin_user))
    assert r.status_code == 200
    r = await client.post(
        f"/api/v1/admin/withdrawals/{wid}/approve",
        headers=_auth(admin_user))
    assert r.status_code == 422
    r = await client.post(
        f"/api/v1/admin/withdrawals/{wid}/reject",
        json={"reason": "x"}, headers=_auth(admin_user))
    assert r.status_code == 422  # approved -> rejected is not allowed


async def test_non_admin_blocked(client, eligible_user, admin_user):
    r = await client.get("/api/v1/admin/withdrawals",
                         headers=_auth(eligible_user))
    assert r.status_code == 403
    await _grant_cash(eligible_user, 1200)
    wid = await _request_withdrawal(eligible_user)
    r = await client.post(
        f"/api/v1/admin/withdrawals/{wid}/approve",
        headers=_auth(eligible_user))
    assert r.status_code == 403
    r = await client.put("/api/v1/admin/earnings/rules", json={},
                         headers=_auth(eligible_user))
    assert r.status_code == 403


async def test_admin_withdrawals_pending_first(client, admin_user):
    u1 = await _mk_user()
    u2 = await _mk_user()
    await _grant_cash(u1, 1500)
    await _grant_cash(u2, 1500)
    w2 = await _request_withdrawal(u2)
    await _request_withdrawal(u1)
    async with SessionLocal() as db:
        await wallet_svc.approve_withdrawal(db, w2)
    r = await client.get("/api/v1/admin/withdrawals",
                         headers=_auth(admin_user))
    assert r.status_code == 200
    items = r.json()["withdrawals"]
    assert items[0]["status"] == "pending"


# ------------------------------------------------------------ ledger independence
async def test_ledgers_independent(client, user):
    async with SessionLocal() as db:
        await rewards_svc.award(db, user, 10, "post_created",
                                f"indep:{uuid.uuid4().hex}")
        # proof-based pivot: share cash is credited via approved claims,
        # never auto — credit directly here to test ledger independence.
        db.add(CashLedger(user_id=user, delta_cents=5,
                          reason="claim_share", ref_id="indep:claim"))
        await db.commit()
    assert await _points(user) == 10
    assert await _cash(user) == 5


# ------------------------------------------------------------ earnings rules
async def test_earnings_rules_get_put(client, admin_user):
    r = await client.get("/api/v1/admin/earnings/rules",
                         headers=_auth(admin_user))
    assert r.status_code == 200
    rules = r.json()["rules"]
    assert rules["share_cents"] == 5
    assert rules["share_click_cents"] == 3
    assert rules["min_withdraw_cents"] == 1000
    assert rules["points_to_cash_per_1000_cents"] == 200

    r = await client.put("/api/v1/admin/earnings/rules",
                         json={"share_cents": 7},
                         headers=_auth(admin_user))
    assert r.status_code == 200
    assert r.json()["rules"]["share_cents"] == 7
    r = await client.get("/api/v1/admin/earnings/rules",
                         headers=_auth(admin_user))
    assert r.json()["rules"]["share_cents"] == 7

    r = await client.put("/api/v1/admin/earnings/rules",
                         json={"share_cents": -1},
                         headers=_auth(admin_user))
    assert r.status_code == 422
    # restore default for other tests
    await client.put("/api/v1/admin/earnings/rules",
                     json={"share_cents": 5}, headers=_auth(admin_user))


# ------------------------------------------------------------ points -> cash
async def test_convert_math_exact(client, user):
    async with SessionLocal() as db:
        await rewards_svc.award(db, user, 2000, "post_created",
                                f"conv:{uuid.uuid4().hex}")
    r = await client.post("/api/v1/wallet/convert", json={"points": 1000},
                          headers=_auth(user))
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["points_debited"] == 1000
    assert data["cash_credited_cents"] == 200   # 500 pts = $1.00 -> 1000 = $2.00
    assert data["cash_display"] == "$2.00"
    assert await _points(user) == 1000
    assert await _cash(user) == 200


async def test_convert_below_minimum_422(client, user):
    async with SessionLocal() as db:
        await rewards_svc.award(db, user, 2000, "post_created",
                                f"conv2:{uuid.uuid4().hex}")
    r = await client.post("/api/v1/wallet/convert", json={"points": 999},
                          headers=_auth(user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "below_minimum"


async def test_convert_insufficient_points_422(client, user):
    r = await client.post("/api/v1/wallet/convert", json={"points": 1000},
                          headers=_auth(user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "insufficient_points"


async def test_convert_atomic_no_partial(client, user):
    async with SessionLocal() as db:
        await rewards_svc.award(db, user, 2000, "post_created",
                                f"conv3:{uuid.uuid4().hex}")
    pts_before = await _points(user)
    cash_before = await _cash(user)
    async with SessionLocal() as db:
        async def boom():
            raise RuntimeError("db down")

        db.commit = boom
        with pytest.raises(RuntimeError):
            await wallet_svc.convert_points_to_cash(db, user, 1000)
        await db.rollback()
    # Neither leg persisted.
    assert await _points(user) == pts_before
    assert await _cash(user) == cash_before
    async with SessionLocal() as db:
        n = (await db.execute(
            select(func.count()).select_from(PointsLedger)
            .where(PointsLedger.reason == "points_to_cash",
                   PointsLedger.user_id == user))).scalar()
        assert n == 0


async def test_converted_cash_counts_toward_withdrawal(client,
                                                      eligible_user):
    async with SessionLocal() as db:
        await rewards_svc.award(db, eligible_user, 5000, "post_created",
                                f"conv4:{uuid.uuid4().hex}")
    r = await client.post("/api/v1/wallet/convert", json={"points": 5000},
                          headers=_auth(eligible_user))
    assert r.status_code == 200
    assert r.json()["cash_credited_cents"] == 1000  # $10.00
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(1000),
                          headers=_auth(eligible_user))
    assert r.status_code == 201, r.text
    assert r.json()["withdrawal"]["status"] == "pending"


# ------------------------------------------------------------ volume bonus
async def _add_clicks(uid, n: int, days_ago: float = 0):
    async with SessionLocal() as db:
        ts = _old_ts(0) - timedelta(days=days_ago)
        for i in range(n):
            db.add(ShareClick(code=f"vb{uuid.uuid4().hex[:10]}",
                              sharer_user_id=uid, asin="B0VOLUME01",
                              viewer_ip_hash=f"vb{i}",
                              created_at=ts))
        await db.commit()


async def test_volume_bonus_idempotent(client, user):
    await _add_clicks(user, 100)
    async with SessionLocal() as db:
        await wallet_svc._check_volume_bonus(db, user)
    assert await _cash(user) == 200  # $2.00 for 100 clicks / 7d
    async with SessionLocal() as db:
        await wallet_svc._check_volume_bonus(db, user)
    assert await _cash(user) == 200  # not paid twice


async def test_volume_progress_counts(client, user):
    await _add_clicks(user, 72)
    r = await client.get("/api/v1/rewards/volume-progress",
                         headers=_auth(user))
    assert r.status_code == 200
    data = r.json()
    assert data["clicks_7d"] >= 72
    first = data["thresholds"][0]
    assert first["clicks"] == 100 and first["cents"] == 200


# ------------------------------------------------------------ top sellers
async def test_top_seller_pays_once_per_period():
    from app.models.billing import SystemSetting
    async with SessionLocal() as db:
        # Disposable test DB, but the suite may run repeatedly: clear
        # competing clicks + watermarks so this test is deterministic.
        await db.execute(delete(ShareClick))
        for key in ("cash.last_settled_seller_week",
                    "cash.last_settled_seller_month"):
            row = (await db.execute(
                select(SystemSetting).where(SystemSetting.key == key)
            )).scalar_one_or_none()
            if row is not None:
                await db.delete(row)
        await db.commit()
    a = await _mk_user(name="Seller A")
    b = await _mk_user(name="Seller B")
    await _add_clicks(a, 10, days_ago=3)   # last week
    await _add_clicks(b, 4, days_ago=3)
    async with SessionLocal() as db:
        paid1 = await wallet_svc.settle_seller_periods(db)
    assert await _cash(a) == 1000   # $10.00 weekly top seller
    assert await _cash(b) == 0
    async with SessionLocal() as db:
        bal_before = await _cash(a)
        paid2 = await wallet_svc.settle_seller_periods(db)
        assert await _cash(a) == bal_before  # watermarked: no double pay
    assert paid2["weekly"] == [] and paid2["monthly"] == []


async def test_seller_leaderboard_ordering():
    x = await _mk_user(name="Seller X")
    y = await _mk_user(name="Seller Y")
    z = await _mk_user(name="Seller Z")
    await _add_clicks(x, 30)
    await _add_clicks(y, 20)
    await _add_clicks(z, 10)
    async with SessionLocal() as db:
        board = await wallet_svc.get_seller_leaderboard(db, "week")
    ids = [e["user_id"] for e in board["leaderboard"]]
    ix, iy, iz = ids.index(str(x)), ids.index(str(y)), ids.index(str(z))
    assert ix < iy < iz  # ordered by verified clicks, desc
    assert board["period"]["prize_cents"] == 1000
    assert board["period"]["prize_display"] == "$10.00"
    clicks = {e["user_id"]: e["verified_clicks"]
              for e in board["leaderboard"]}
    assert clicks[str(x)] >= 30 and clicks[str(y)] >= 20


async def test_seller_winners_endpoint(client):
    r = await client.get("/api/v1/rewards/seller-winners",
                         headers=_auth(await _mk_user()))
    assert r.status_code == 200
    assert isinstance(r.json()["winners"], list)


# ------------------------------------------------------------ methods registry
async def test_methods_endpoint_defaults(client, user):
    r = await client.get("/api/v1/wallet/methods", headers=_auth(user))
    assert r.status_code == 200
    methods = {m["id"]: m for m in r.json()["methods"]}
    assert set(methods) == {"bank_transfer", "easypaisa", "jazzcash",
                            "paypal", "payoneer", "crypto_usdt"}
    assert methods["bank_transfer"]["enabled"] is True
    assert methods["easypaisa"]["enabled"] is True
    assert methods["jazzcash"]["enabled"] is True
    assert methods["paypal"]["enabled"] is False
    assert methods["crypto_usdt"]["fields"][-1]["options"] == [
        "TRC20", "ERC20", "BEP20"]


async def test_admin_method_toggle_and_disabled_rejected(client, user,
                                                        admin_user):
    await _grant_cash(user, 1500)
    # paypal disabled by default -> rejected
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(
                              1000, method_id="paypal",
                              details={"email": "h@example.com"}),
                          headers=_auth(user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "method_disabled"

    # admin enables it
    r = await client.put("/api/v1/admin/earnings/methods",
                         json={"paypal": True}, headers=_auth(admin_user))
    assert r.status_code == 200
    assert {m["id"]: m["enabled"] for m in r.json()["methods"]}[
        "paypal"] is True

    # now it works
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(
                              1000, method_id="paypal",
                              details={"email": "h@example.com"}),
                          headers=_auth(user))
    assert r.status_code == 201, r.text

    # unknown method id rejected by the admin toggle too
    r = await client.put("/api/v1/admin/earnings/methods",
                         json={"western_union": True},
                         headers=_auth(admin_user))
    assert r.status_code == 422

    # restore default
    r = await client.put("/api/v1/admin/earnings/methods",
                         json={"paypal": False}, headers=_auth(admin_user))
    assert r.status_code == 200


async def test_crypto_network_option_validated(client, eligible_user,
                                               admin_user):
    await _grant_cash(eligible_user, 1500)
    # crypto_usdt is disabled by default -> enable it first
    await client.put("/api/v1/admin/earnings/methods",
                     json={"crypto_usdt": True}, headers=_auth(admin_user))
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(
                              1000, method_id="crypto_usdt",
                              details={"wallet_address": "TXyz",
                                       "network": "DOGE"}),
                          headers=_auth(eligible_user))
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "invalid_method"
    # valid network works
    r = await client.post("/api/v1/wallet/withdraw",
                          json=_withdraw_body(
                              1000, method_id="crypto_usdt",
                              details={"wallet_address": "TXyz",
                                       "network": "TRC20"}),
                          headers=_auth(eligible_user))
    assert r.status_code == 201, r.text
    await client.put("/api/v1/admin/earnings/methods",
                     json={"crypto_usdt": False}, headers=_auth(admin_user))


# ------------------------------------------------------------ payout wall
async def _full_payout(uid, cents=1000) -> None:
    """Request -> approve -> paid, end to end."""
    admin = await _mk_user(name="Admin", admin=True)
    await _grant_cash(uid, cents + 500)
    async with SessionLocal() as db:
        user = (await db.execute(
            select(User).where(User.id == uid))).scalar_one()
        w = await wallet_svc.request_withdrawal(
            db, user, cents, "easypaisa",
            {"mobile_number": "03451234567", "account_title": "Hafiz"},
            age_confirmed=True)
        await wallet_svc.approve_withdrawal(db, w.id)
        await wallet_svc.mark_withdrawal_paid(db, w.id, "REF-1")


async def test_payout_wall_only_paid_masked_no_pii(client):
    u_paid = await _mk_user(name="Ahmed Khan")
    u_pending = await _mk_user(name="Bilal Ahmed")
    await _full_payout(u_paid, 1500)
    await _grant_cash(u_pending, 2000)
    await _request_withdrawal(u_pending)  # stays pending

    # PUBLIC: no auth needed
    r = await client.get("/api/v1/rewards/payouts")
    assert r.status_code == 200
    data = r.json()
    assert data["total"] >= 1
    entry = next(e for e in data["payouts"]
                 if e["amount_cents"] == 1500)
    assert entry["masked_name"] == "Ahmed K."
    assert entry["method_id"] == "easypaisa"
    assert entry["paid_at"]
    blob = str(data)
    # PII must never leak on the wall
    assert "Ahmed Khan" not in blob
    assert "Bilal Ahmed" not in blob
    assert "03451234567" not in blob
    assert "PK36" not in blob
    # pending withdrawals never appear
    assert not any(e["masked_name"] == "Bilal A."
                   for e in data["payouts"])


async def test_payout_wall_empty_state_shape(client):
    r = await client.get("/api/v1/rewards/payouts?limit=5&offset=99999")
    assert r.status_code == 200
    assert r.json()["payouts"] == []
    assert r.json()["total"] >= 0


async def test_mask_name_variants():
    assert wallet_svc.mask_name("Ahmed Khan") == "Ahmed K."
    assert wallet_svc.mask_name("Fatima") == "Fatima"
    assert wallet_svc.mask_name("Virello user") == "A Virello member"
    assert wallet_svc.mask_name("") == "A Virello member"
    assert wallet_svc.mask_name(None) == "A Virello member"


# ------------------------------------------------------------ timeline + notifications
async def test_withdrawal_timeline_timestamps(client, eligible_user,
                                             admin_user):
    await _grant_cash(eligible_user, 1500)
    wid = await _request_withdrawal(eligible_user)
    r = await client.get("/api/v1/wallet/withdrawals",
                         headers=_auth(eligible_user))
    w = next(x for x in r.json()["withdrawals"] if x["id"] == str(wid))
    assert w["status"] == "pending"
    assert w["created_at"] and not w["approved_at"] and not w["paid_at"]

    await client.post(f"/api/v1/admin/withdrawals/{wid}/approve",
                      headers=_auth(admin_user))
    r = await client.get("/api/v1/wallet/withdrawals",
                         headers=_auth(eligible_user))
    w = next(x for x in r.json()["withdrawals"] if x["id"] == str(wid))
    assert w["status"] == "approved"
    assert w["approved_at"] and not w["paid_at"]

    await client.post(f"/api/v1/admin/withdrawals/{wid}/mark-paid",
                      json={"payment_ref": "R1"},
                      headers=_auth(admin_user))
    r = await client.get("/api/v1/wallet/withdrawals",
                         headers=_auth(eligible_user))
    w = next(x for x in r.json()["withdrawals"] if x["id"] == str(wid))
    assert w["status"] == "paid"
    assert w["created_at"] and w["approved_at"] and w["paid_at"]


async def test_notifications_on_approve_and_paid(client, eligible_user,
                                                admin_user):
    await _grant_cash(eligible_user, 1500)
    wid = await _request_withdrawal(eligible_user)
    await client.post(f"/api/v1/admin/withdrawals/{wid}/approve",
                      headers=_auth(admin_user))
    await client.post(f"/api/v1/admin/withdrawals/{wid}/mark-paid",
                      json={"payment_ref": "R2"},
                      headers=_auth(admin_user))
    r = await client.get("/api/v1/notifications",
                         headers=_auth(eligible_user))
    assert r.status_code == 200
    kinds = [n["kind"] for n in r.json()["notifications"]]
    assert "withdrawal_approved" in kinds
    assert "withdrawal_paid" in kinds
    nid = r.json()["notifications"][0]["id"]
    r = await client.post(f"/api/v1/notifications/{nid}/read",
                          headers=_auth(eligible_user))
    assert r.status_code == 200

    # other users see nothing of it
    other = await _mk_user()
    r = await client.get("/api/v1/notifications",
                         headers=_auth(other))
    assert r.json()["notifications"] == []
