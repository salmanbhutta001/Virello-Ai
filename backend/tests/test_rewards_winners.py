"""Weekly/monthly POSTER contests (points): settlement, prizes, idempotency."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, func, select

from app.core.database import SessionLocal
from app.core.security import create_token
from app.main import app
from app.models.billing import SystemSetting
from app.models.core import User
from app.models.rewards import PointsLedger
from app.services import rewards as rewards_svc


async def _reset_contest_watermarks() -> None:
    """Dev DB persists across runs — clear watermarks so settlement tests
    are deterministic no matter how often the suite runs."""
    async with SessionLocal() as db:
        for key in ("rewards.last_settled_week", "rewards.last_settled_month",
                    "cash.last_settled_seller_week",
                    "cash.last_settled_seller_month"):
            row = (await db.execute(
                select(SystemSetting).where(SystemSetting.key == key)
            )).scalar_one_or_none()
            if row is not None:
                await db.delete(row)
        await db.commit()


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


def _auth(uid) -> dict:
    return {"Authorization": f"Bearer {create_token(str(uid), timedelta(minutes=30))}"}


async def _mk_user() -> uuid.UUID:
    async with SessionLocal() as db:
        u = User(email=f"win_{uuid.uuid4().hex[:8]}@test.com",
                 name="Winner", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        return u.id


async def _points(uid) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(PointsLedger.delta), 0))
            .where(PointsLedger.user_id == uid))).scalar() or 0


def _last_week_ts() -> datetime:
    # A naive-UTC timestamp squarely inside the previous calendar week.
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    monday = now - timedelta(days=now.weekday())
    return monday - timedelta(days=3)


async def _grant_points_last_week(uid, pts: int) -> None:
    async with SessionLocal() as db:
        db.add(PointsLedger(user_id=uid, delta=pts, reason="post_created",
                            ref_id=f"ww:{uuid.uuid4().hex}",
                            created_at=_last_week_ts()))
        await db.commit()


async def _clear_points_window(start: datetime, end: datetime) -> None:
    """Delete points rows in [start, end) so repeated suite runs can't
    tie with this run's winners."""
    async with SessionLocal() as db:
        await db.execute(delete(PointsLedger).where(
            PointsLedger.created_at >= start,
            PointsLedger.created_at < end))
        await db.commit()


async def test_weekly_winners_paid_500_300_150():
    await _reset_contest_watermarks()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    monday = now - timedelta(days=now.weekday())
    last_monday = monday - timedelta(days=7)
    await _clear_points_window(last_monday, monday)
    a, b, c = await _mk_user(), await _mk_user(), await _mk_user()
    await _grant_points_last_week(a, 100000)
    await _grant_points_last_week(b, 60000)
    await _grant_points_last_week(c, 30000)
    async with SessionLocal() as db:
        paid = await rewards_svc.settle_periods(db)
    assert await _points(a) == 100000 + 500
    assert await _points(b) == 60000 + 300
    assert await _points(c) == 30000 + 150
    assert paid["weekly"], "expected a weekly settlement"


async def test_winner_payouts_idempotent():
    a = await _mk_user()
    await _grant_points_last_week(a, 200000)
    async with SessionLocal() as db:
        before = await _points(a)
        await rewards_svc.settle_periods(db)
        after_first = await _points(a)
        paid = await rewards_svc.settle_periods(db)
        after_second = await _points(a)
    assert after_first >= before          # settled at least once overall
    assert after_second == after_first   # never paid twice
    assert paid["weekly"] == [] and paid["monthly"] == []


async def test_monthly_winners_paid_2000_1000_500():
    await _reset_contest_watermarks()
    first_this_month = datetime.now(timezone.utc).replace(
        tzinfo=None, day=1, hour=12)
    last_month_start = (first_this_month.replace(day=1)
                        - timedelta(days=1)).replace(day=1)
    await _clear_points_window(last_month_start, first_this_month.replace(
        day=1, hour=0, minute=0, second=0, microsecond=0))
    a, b, c = await _mk_user(), await _mk_user(), await _mk_user()
    last_month = (first_this_month - timedelta(days=15)).replace(day=15)
    async with SessionLocal() as db:
        for uid, pts in ((a, 90000), (b, 50000), (c, 20000)):
            db.add(PointsLedger(user_id=uid, delta=pts, reason="post_created",
                                ref_id=f"wm:{uuid.uuid4().hex}",
                                created_at=last_month))
        await db.commit()
    async with SessionLocal() as db:
        await rewards_svc.settle_periods(db)
    assert await _points(a) == 90000 + 2000
    assert await _points(b) == 50000 + 1000
    assert await _points(c) == 20000 + 500


async def test_winners_endpoint_lists_past_winners(client):
    r = await client.get("/api/v1/rewards/winners",
                         headers=_auth(await _mk_user()))
    assert r.status_code == 200
    winners = r.json()["winners"]
    assert isinstance(winners, list)
    assert winners, "expected winners from the settlement tests above"
    assert winners[0]["points"] in (500, 300, 150, 2000, 1000, 500)


async def test_leaderboard_period_param(client):
    uid = await _mk_user()
    for period in ("week", "month", "rolling"):
        r = await client.get(
            f"/api/v1/rewards/leaderboard?period={period}",
            headers=_auth(uid))
        assert r.status_code == 200, period
        data = r.json()
        assert data["period"]["scope"] == period
        assert "prizes" in data["period"]
        assert isinstance(data["leaderboard"], list)
