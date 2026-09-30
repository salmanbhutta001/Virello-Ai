"""Share-to-earn (CASH): share links, click logging, cash rewards, caps.

Story line: "Post karo -> points. Share karo, bikwao -> cash."
Share actions NEVER touch the points ledger.
"""
from __future__ import annotations

import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select

from app.core.database import SessionLocal
from app.core.security import create_token
from app.main import app
from app.models.commerce import Product
from app.models.core import User
from app.models.rewards import PointsLedger, ShareClick
from app.models.wallet import CashLedger
from app.services.affiliate.amazon import AmazonAffiliateProvider


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def user():
    async with SessionLocal() as db:
        u = User(email=f"se_{uuid.uuid4().hex[:8]}@test.com",
                 name="Share Tester", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    yield uid


def _auth(uid) -> dict:
    token = create_token(str(uid), timedelta(minutes=30))
    return {"Authorization": f"Bearer {token}"}


_TEST_ASIN = "B0SHARE123"


async def _add_product(owner_id, asin: str):
    async with SessionLocal() as db:
        url = AmazonAffiliateProvider().build_affiliate_url(asin)
        # get-or-create: the catalog lookup expects exactly one active row
        # per affiliate URL, and the DB persists across tests in this file.
        existing = (await db.execute(
            select(Product.id).where(Product.affiliate_url == url)
        )).scalar_one_or_none()
        if existing is not None:
            return existing
        p = Product(creator_id=owner_id, title=f"Share test {asin}",
                    affiliate_url=url, is_active=True)
        db.add(p)
        await db.commit()
        await db.refresh(p)
        return p.id


@pytest_asyncio.fixture
async def product(user):
    yield await _add_product(user, _TEST_ASIN)


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


async def _share_clicks_for(code: str) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.count()).select_from(ShareClick)
            .where(ShareClick.code == code))).scalar() or 0


async def _other_user() -> uuid.UUID:
    async with SessionLocal() as db:
        u = User(email=f"sev_{uuid.uuid4().hex[:8]}@test.com",
                 name="Viewer", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        return u.id


async def test_share_link_format_and_tampered_404(client, user, product):
    r = await client.post("/api/v1/rewards/share-link",
                          json={"asin": _TEST_ASIN}, headers=_auth(user))
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["share_url"] == (
        f"https://virello-api-production.up.railway.app/s/{data['code']}")
    assert data["asin"] == _TEST_ASIN

    tampered = data["code"][:-1] + ("A" if data["code"][-1] != "A" else "B")
    assert (await client.get(f"/s/{tampered}")).status_code == 404
    assert (await client.get("/s/not-a-code")).status_code == 404


async def test_share_link_302_logs_and_pays_cash(client, user, product):
    r = await client.post("/api/v1/rewards/share-link",
                          json={"asin": _TEST_ASIN}, headers=_auth(user))
    code = r.json()["code"]
    viewer = await _other_user()
    cash_before = await _cash(user)
    pts_before = await _points(user)

    r2 = await client.get(f"/s/{code}", headers=_auth(viewer),
                          follow_redirects=False)
    assert r2.status_code == 302
    assert r2.headers["location"].endswith(f"/api/v1/shop/go/{_TEST_ASIN}")
    assert await _share_clicks_for(code) == 1
    assert await _cash(user) == cash_before + 3      # $0.03 per click
    assert await _points(user) == pts_before          # points untouched

    # Same viewer, same link, same day: logged, no double pay
    r3 = await client.get(f"/s/{code}", headers=_auth(viewer),
                          follow_redirects=False)
    assert r3.status_code == 302
    assert await _share_clicks_for(code) == 2
    assert await _cash(user) == cash_before + 3


async def test_self_share_click_pays_zero(client, user, product):
    r = await client.post("/api/v1/rewards/share-link",
                          json={"asin": _TEST_ASIN}, headers=_auth(user))
    code = r.json()["code"]
    cash_before = await _cash(user)
    r2 = await client.get(f"/s/{code}", headers=_auth(user),
                          follow_redirects=False)
    assert r2.status_code == 302
    assert await _cash(user) == cash_before


async def test_share_completed_is_claim_based_410_no_auto_credit(
        client, user, product):
    """Proof-based pivot: POST /rewards/share no longer auto-credits.
    Old clients get 410 + guidance; the cash balance is untouched."""
    cash_before = await _cash(user)
    r = await client.post("/api/v1/rewards/share",
                          json={"asin": _TEST_ASIN}, headers=_auth(user))
    assert r.status_code == 410, r.text
    body = r.json()["detail"]
    assert body["error"] == "share_rewards_are_claim_based"
    assert body["claim_endpoint"] == "/api/v1/rewards/claim"
    assert await _cash(user) == cash_before


async def test_share_click_daily_cap_50(client, user, product):
    r = await client.post("/api/v1/rewards/share-link",
                          json={"asin": _TEST_ASIN}, headers=_auth(user))
    code = r.json()["code"]
    cash_before = await _cash(user)
    for _ in range(50):
        viewer = await _other_user()
        r2 = await client.get(f"/s/{code}", headers=_auth(viewer),
                              follow_redirects=False)
        assert r2.status_code == 302
    assert await _cash(user) == cash_before + 50 * 3
    # 51st distinct viewer: logged, over the daily cap -> 0
    viewer = await _other_user()
    r2 = await client.get(f"/s/{code}", headers=_auth(viewer),
                          follow_redirects=False)
    assert r2.status_code == 302
    assert await _share_clicks_for(code) == 51
    assert await _cash(user) == cash_before + 50 * 3


async def test_share_link_unknown_asin_404(client, user):
    r = await client.post("/api/v1/rewards/share-link",
                          json={"asin": "B0NOPE0000"}, headers=_auth(user))
    assert r.status_code == 404
    # proof-based pivot: /rewards/share no longer auto-credits (410), even
    # for unknown ASINs — the endpoint is gone, file a claim instead.
    r = await client.post("/api/v1/rewards/share",
                          json={"asin": "B0NOPE0000"}, headers=_auth(user))
    assert r.status_code == 410


async def test_share_stats_cash(client, user, product):
    # proof-based pivot: /rewards/share pays nothing (410); only verified
    # share-link clicks still earn cash automatically.
    r = await client.post("/api/v1/rewards/share",
                          json={"asin": _TEST_ASIN}, headers=_auth(user))
    assert r.status_code == 410
    r = await client.post("/api/v1/rewards/share-link",
                          json={"asin": _TEST_ASIN}, headers=_auth(user))
    code = r.json()["code"]
    viewer = await _other_user()
    await client.get(f"/s/{code}", headers=_auth(viewer),
                     follow_redirects=False)
    r = await client.get("/api/v1/rewards/share-stats", headers=_auth(user))
    assert r.status_code == 200
    data = r.json()
    assert data["products_shared"] == 0
    assert data["share_clicks"] == 1
    assert data["cents_from_shares"] == 3
    assert data["cash_display"] == "$0.03"


async def test_volume_progress_endpoint(client, user, product):
    r = await client.get("/api/v1/rewards/volume-progress",
                         headers=_auth(user))
    assert r.status_code == 200
    data = r.json()
    assert "clicks_7d" in data
    assert data["thresholds"][0]["clicks"] == 100
    assert data["thresholds"][0]["cents"] == 200
