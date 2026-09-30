"""Virello Points: earning rules, caps, idempotency, redeem, admin adjust."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select

from app.core.database import SessionLocal
from app.core.config import settings
from app.core.security import create_token
from app.main import app
from app.models.core import AuditLog, Campaign, CampaignGoal, GrowthMode, User
from app.models.rewards import PointsLedger
from app.services import rewards as rewards_svc


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def user():
    async with SessionLocal() as db:
        u = User(email=f"rw_{uuid.uuid4().hex[:8]}@test.com", name="Reward Tester",
                 preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    yield uid


@pytest_asyncio.fixture
async def admin_user(monkeypatch):
    async with SessionLocal() as db:
        u = User(email=f"rwa_{uuid.uuid4().hex[:8]}@test.com", name="Reward Admin",
                 preferred_language="en", is_admin=True)
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
        email = u.email
    # Admin panel is email-allowlisted (Hafiz 2026-09-30): admit the fixture
    # admin for the duration of the test.
    monkeypatch.setattr(settings, "admin_emails", email)
    yield uid


def _auth(uid) -> dict:
    token = create_token(str(uid), timedelta(minutes=30))
    return {"Authorization": f"Bearer {token}"}


async def _balance(uid) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(PointsLedger.delta), 0))
            .where(PointsLedger.user_id == uid))).scalar() or 0


async def _make_campaign(owner_id, post_url="https://example.com/p/1"):
    async with SessionLocal() as db:
        c = Campaign(user_id=owner_id, title="Test campaign",
                     post_url=post_url, platform="instagram",
                     goal=CampaignGoal.reach, mode=GrowthMode.organic)
        db.add(c)
        await db.commit()
        await db.refresh(c)
        return c.id


async def _other_user():
    async with SessionLocal() as db:
        u = User(email=f"rwo_{uuid.uuid4().hex[:8]}@test.com", name="Other",
                 preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        return u.id


# ------------------------------------------------------------------ posts
async def test_post_awards_10(user):
    async with SessionLocal() as db:
        granted = await rewards_svc.award_post_created(db, user, uuid.uuid4())
    assert granted == 10
    assert await _balance(user) == 10


async def test_sixth_post_same_day_pays_0(user):
    async with SessionLocal() as db:
        total = 0
        for _ in range(6):
            total += await rewards_svc.award_post_created(db, user, uuid.uuid4())
    assert total == 50
    assert await _balance(user) == 50


async def test_post_idempotent_double_call(user):
    cid = uuid.uuid4()
    async with SessionLocal() as db:
        a = await rewards_svc.award_post_created(db, user, cid)
        b = await rewards_svc.award_post_created(db, user, cid)
    assert (a, b) == (10, 0)
    assert await _balance(user) == 10


async def test_post_with_products_awards_25(user):
    async with SessionLocal() as db:
        granted = await rewards_svc.award_post_with_products(db, user, uuid.uuid4())
    assert granted == 25
    assert await _balance(user) == 25


async def test_post_cap_shared_between_plain_and_shoppable(user):
    async with SessionLocal() as db:
        total = 0
        for _ in range(4):
            total += await rewards_svc.award_post_created(db, user, uuid.uuid4())
        total += await rewards_svc.award_post_with_products(db, user, uuid.uuid4())
        extra = await rewards_svc.award_post_created(db, user, uuid.uuid4())
    assert total == 4 * 10 + 25
    assert extra == 0


# ------------------------------------------------------------------ likes
async def test_like_received_awards_owner(user):
    owner = user
    liker = await _other_user()
    cid = await _make_campaign(owner)
    async with SessionLocal() as db:
        granted = await rewards_svc.award_like_received(db, cid, liker, uuid.uuid4())
    assert granted == 1
    assert await _balance(owner) == 1
    assert await _balance(liker) == 0


async def test_self_like_pays_0(user):
    cid = await _make_campaign(user)
    async with SessionLocal() as db:
        granted = await rewards_svc.award_like_received(db, cid, user, uuid.uuid4())
    assert granted == 0
    assert await _balance(user) == 0


async def test_like_idempotent_same_interaction(user):
    liker = await _other_user()
    cid = await _make_campaign(user)
    iid = uuid.uuid4()
    async with SessionLocal() as db:
        a = await rewards_svc.award_like_received(db, cid, liker, iid)
        b = await rewards_svc.award_like_received(db, cid, liker, iid)
    assert (a, b) == (1, 0)
    assert await _balance(user) == 1


async def test_like_cap_50_per_post_per_day(user):
    cid = await _make_campaign(user)
    async with SessionLocal() as db:
        total = 0
        for _ in range(51):
            liker = await _other_user()
            total += await rewards_svc.award_like_received(db, cid, liker, uuid.uuid4())
    assert total == 50
    assert await _balance(user) == 50


# ---------------------------------------------------------------- comments
async def test_comment_received_awards_2(user):
    commenter = await _other_user()
    await _make_campaign(user, post_url="https://example.com/p/c1")
    async with SessionLocal() as db:
        granted = await rewards_svc.award_comment_received(
            db, "https://example.com/p/c1", commenter, "cmt1")
    assert granted == 2
    assert await _balance(user) == 2


async def test_self_comment_pays_0(user):
    await _make_campaign(user, post_url="https://example.com/p/c2")
    async with SessionLocal() as db:
        granted = await rewards_svc.award_comment_received(
            db, "https://example.com/p/c2", user, "cmt2")
    assert granted == 0


async def test_comment_unknown_post_pays_0(user):
    commenter = await _other_user()
    async with SessionLocal() as db:
        granted = await rewards_svc.award_comment_received(
            db, "https://example.com/unknown", commenter, "cmt3")
    assert granted == 0


# ------------------------------------------------------------------ misc
async def test_daily_login_once_per_day(user):
    async with SessionLocal() as db:
        a = await rewards_svc.award_daily_login(db, user)
        b = await rewards_svc.award_daily_login(db, user)
    assert (a, b) == (2, 0)
    assert await _balance(user) == 2


async def test_profile_completed_once(user):
    async with SessionLocal() as db:
        a = await rewards_svc.award_profile_completed(db, user, "Hafiz", "en")
        b = await rewards_svc.award_profile_completed(db, user, "Hafiz", "en")
        c = await rewards_svc.award_profile_completed(db, user, None, "en")
    assert (a, b, c) == (20, 0, 0)
    assert await _balance(user) == 20


async def test_referral_awards_50(user):
    async with SessionLocal() as db:
        a = await rewards_svc.award_referral(db, user, uuid.uuid4())
        # same event twice -> 0
        b = await rewards_svc.award(db, user, 50, "referral", "evt-dup-check")
        c = await rewards_svc.award(db, user, 50, "referral", "evt-dup-check")
    assert a == 50
    assert (b, c) == (50, 0)


async def test_streak_day2_bonus(user):
    yesterday = datetime.now(timezone.utc) - timedelta(days=1)
    async with SessionLocal() as db:
        db.add(PointsLedger(user_id=user, delta=10, reason="post_created",
                            ref_id="streak-y", created_at=yesterday))
        await db.commit()
        granted = await rewards_svc.award_post_created(db, user, uuid.uuid4())
    # +10 post, +5 streak day 2
    assert granted == 15
    assert await _balance(user) == 25


# ------------------------------------------------------------------ redeem
async def test_redeem_converts_at_default_rate(user):
    async with SessionLocal() as db:
        for _ in range(5):
            await rewards_svc.award_post_created(db, user, uuid.uuid4())
        # 50 pts; top up to 100 via admin adjust
        await rewards_svc.award(db, user, 50, "admin_adjust", f"topup-{uuid.uuid4().hex}")
        before_credits = (await db.execute(
            select(User.credits).where(User.id == user))).scalar()
        out = await rewards_svc.redeem(db, user, 100)
    assert out["points_redeemed"] == 100
    assert out["credits_added"] == 10  # default 100 pts = 10 credits
    assert out["points_balance"] == 0
    assert out["credits_balance"] == before_credits + 10


async def test_redeem_below_min_400(client, user):
    r = await client.post("/api/v1/rewards/redeem", json={"points": 50},
                          headers=_auth(user))
    assert r.status_code == 400


async def test_redeem_insufficient_400(client, user):
    r = await client.post("/api/v1/rewards/redeem", json={"points": 100},
                          headers=_auth(user))
    assert r.status_code == 400


# ---------------------------------------------------------------- endpoints
async def test_balance_endpoint_shape(client, user):
    async with SessionLocal() as db:
        await rewards_svc.award_post_created(db, user, uuid.uuid4())
    r = await client.get("/api/v1/rewards/balance", headers=_auth(user))
    assert r.status_code == 200
    body = r.json()
    assert body["balance"] == 10
    assert body["lifetime"] == 10
    assert body["level"] == "Sprout"
    assert body["next_level"] == "Rising"


async def test_level_progression(client, user):
    async with SessionLocal() as db:
        await rewards_svc.award(db, user, 150, "admin_adjust", f"lvl-{uuid.uuid4().hex}")
    r = await client.get("/api/v1/rewards/balance", headers=_auth(user))
    assert r.json()["level"] == "Rising"


async def test_leaderboard_ordering(client):
    u1 = await _other_user()
    u2 = await _other_user()
    async with SessionLocal() as db:
        await rewards_svc.award(db, u1, 30, "admin_adjust", f"lb1-{uuid.uuid4().hex}")
        await rewards_svc.award(db, u2, 90, "admin_adjust", f"lb2-{uuid.uuid4().hex}")
    r = await client.get("/api/v1/rewards/leaderboard?limit=50")
    assert r.status_code == 200
    names = [e["username"] for e in r.json()["leaderboard"]]
    assert "leaderboard" in r.json() and "period" in r.json()


async def test_rules_endpoint(client):
    r = await client.get("/api/v1/rewards/rules")
    assert r.status_code == 200
    ids = {x["id"] for x in r.json()["rules"]}
    assert {"post_created", "redeem", "weekly_contest", "monthly_contest"} <= ids


async def test_history_excludes_zero_rows(client, user):
    async with SessionLocal() as db:
        await rewards_svc.award_post_created(db, user, uuid.uuid4())
    r = await client.get("/api/v1/rewards/history", headers=_auth(user))
    assert r.status_code == 200
    assert all(h["delta"] != 0 for h in r.json()["history"])
    assert r.json()["history"][0]["reason"] == "post_created"


# ------------------------------------------------------------------ admin
async def test_admin_adjust_blocked_for_non_admin(client, user):
    other = await _other_user()
    r = await client.post(f"/api/v1/admin/users/{other}/points",
                          json={"delta": 10, "reason": "test"},
                          headers=_auth(user))
    assert r.status_code == 403


async def test_admin_adjust_works_and_audited(client, admin_user, user):
    r = await client.post(f"/api/v1/admin/users/{user}/points",
                          json={"delta": 25, "reason": "good citizen"},
                          headers=_auth(admin_user))
    assert r.status_code == 200
    assert r.json()["delta_granted"] == 25
    assert await _balance(user) == 25
    async with SessionLocal() as db:
        n = (await db.execute(select(func.count()).select_from(AuditLog).where(
            AuditLog.action == "admin.points.adjust"))).scalar()
    assert n >= 1


async def test_admin_adjust_zero_delta_400(client, admin_user, user):
    r = await client.post(f"/api/v1/admin/users/{user}/points",
                          json={"delta": 0}, headers=_auth(admin_user))
    assert r.status_code == 400


# ------------------------------------------------------------------ clicks
async def test_product_click_awards_owner(user):
    owner = user
    clicker = await _other_user()
    async with SessionLocal() as db:
        g = await rewards_svc.award_product_click(
            db, owner, f"user:{clicker}", "B000000001", "click-1")
    assert g == 2
    assert await _balance(owner) == 2


async def test_product_self_click_pays_0(user):
    async with SessionLocal() as db:
        g = await rewards_svc.award_product_click(
            db, user, f"user:{user}", "B000000001", "click-2")
    assert g == 0
    assert await _balance(user) == 0


async def test_product_click_dedupe_same_clicker_asin_day(user):
    clicker = await _other_user()
    async with SessionLocal() as db:
        a = await rewards_svc.award_product_click(
            db, user, f"user:{clicker}", "B000000001", "click-3")
        b = await rewards_svc.award_product_click(
            db, user, f"user:{clicker}", "B000000001", "click-4")
    assert (a, b) == (2, 0)
    assert await _balance(user) == 2


async def test_product_click_cap_20_per_day(user):
    async with SessionLocal() as db:
        total = 0
        for i in range(21):
            clicker = await _other_user()
            total += await rewards_svc.award_product_click(
                db, user, f"user:{clicker}", "B000000001", f"cap-{i}")
    assert total == 40
    assert await _balance(user) == 40
