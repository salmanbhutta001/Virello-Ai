"""Shoppable posts: tag Amazon products on feed posts + click tracking + rewards.

Real data only: ASINs below are obviously-fake-but-valid-format
(B000000001 ...) and each gets a real Product row whose affiliate_url is
built by the production AmazonAffiliateProvider — nothing invented.

Reward semantics follow the live codebase: tagged posts earn +25 points
via rewards.award_post_with_products; product clicks pay the post owner
cash (3 cents, 50/day cap, no self-clicks) via
wallet.award_product_click_cash.
"""
from __future__ import annotations

import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select

from app.core.database import SessionLocal
from app.core.config import settings
from app.core.security import create_token
from app.main import app
from app.models.commerce import PostProduct, Product, ShopClick
from app.models.core import Campaign, CampaignGoal, CampaignStatus, GrowthMode, User
from app.models.growth import DiscoveryPlacement
from app.models.rewards import PointsLedger
from app.models.wallet import CashLedger
from app.services.affiliate.amazon import AmazonAffiliateProvider
from app.services.discovery.service import get_feed

ASIN_1 = "B000000001"
ASIN_2 = "B000000002"
ASIN_3 = "B000000003"

_provider = AmazonAffiliateProvider()


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def user():
    async with SessionLocal() as db:
        u = User(email=f"shop_{uuid.uuid4().hex[:8]}@test.com",
                 name="Shopper", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    yield uid


@pytest_asyncio.fixture
async def admin_user(monkeypatch):
    async with SessionLocal() as db:
        u = User(email=f"shopa_{uuid.uuid4().hex[:8]}@test.com",
                 name="Shop Admin", preferred_language="en", is_admin=True)
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
    return {"Authorization": f"Bearer {create_token(str(uid), timedelta(minutes=30))}"}


async def _make_campaign(owner_id, live: bool = False):
    async with SessionLocal() as db:
        c = Campaign(user_id=owner_id, title="Shoppable test post",
                     post_url=f"https://example.com/shop-{uuid.uuid4().hex[:8]}",
                     platform="instagram", goal=CampaignGoal.reach,
                     mode=GrowthMode.organic)
        if live:
            c.status = CampaignStatus.live
        db.add(c)
        await db.commit()
        await db.refresh(c)
        return c.id


async def _make_product(asin: str, creator_id) -> str:
    """Idempotent fixture product: the catalog is ASIN-deduped, so reuse
    an existing row for the same affiliate URL."""
    url = _provider.build_affiliate_url(asin)
    async with SessionLocal() as db:
        existing = (await db.execute(select(Product).where(
            Product.affiliate_url == url))).scalar_one_or_none()
        if existing is not None:
            return str(existing.id)
        p = Product(creator_id=creator_id, title=f"Test product {asin}",
                    description="test", price_cents=1299, currency="USD",
                    category="tech", image_urls=["https://example.com/img1.jpg"],
                    is_active=True, is_affiliate=True,
                    affiliate_provider="amazon", affiliate_url=url)
        db.add(p)
        await db.commit()
        await db.refresh(p)
        return str(p.id)


async def _click_balance(uid) -> int:
    """Owner's product_click earnings in cash cents (wallet semantics)."""
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(CashLedger.delta_cents), 0))
            .where(CashLedger.user_id == uid,
                   CashLedger.reason == "product_click"))).scalar() or 0


async def _opt_in(client, uid, campaign_id, asins):
    r = await client.post(
        "/api/v1/discovery/placements",
        json={"campaign_id": campaign_id, "topics": ["technology"],
              "asins": asins},
        headers=_auth(uid))
    return r


# ---------------------------------------------------------------- tagging
async def test_tag_products_on_post(client, user):
    cid = await _make_campaign(user)
    await _make_product(ASIN_1, user)
    await _make_product(ASIN_2, user)
    r = await _opt_in(client, user, str(cid), [ASIN_1, ASIN_2])
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["points_earned"] == 25
    assert sorted(body["asins"]) == [ASIN_1, ASIN_2]
    async with SessionLocal() as db:
        rows = (await db.execute(select(PostProduct).where(
            PostProduct.post_id == uuid.UUID(body["placement_id"])))
        ).scalars().all()
    assert sorted(p.asin for p in rows) == [ASIN_1, ASIN_2]


async def test_tag_invalid_asin_400(client, user):
    # Valid format but not in the catalog.
    cid = await _make_campaign(user)
    r = await _opt_in(client, user, str(cid), ["B000009999"])
    assert r.status_code == 400, r.text
    # Bad format.
    cid2 = await _make_campaign(user)
    r = await _opt_in(client, user, str(cid2), ["not-an-asin"])
    assert r.status_code == 400, r.text


async def test_tag_more_than_5_asins_400(client, user):
    cid = await _make_campaign(user)
    await _make_product(ASIN_1, user)
    r = await _opt_in(client, user, str(cid),
                      [ASIN_1, ASIN_2, ASIN_3, "B000000004",
                       "B000000005", "B000000006"])
    assert r.status_code == 400, r.text


async def test_untagged_post_still_earns_10(client, user):
    cid = await _make_campaign(user)
    r = await _opt_in(client, user, str(cid), [])
    assert r.status_code == 201, r.text
    assert r.json()["points_earned"] == 10


# ---------------------------------------------------------------- redirect
async def test_go_redirect_and_click_logged(client, user):
    cid = await _make_campaign(user)
    await _make_product(ASIN_1, user)
    r = await _opt_in(client, user, str(cid), [ASIN_1])
    pid = r.json()["placement_id"]

    r = await client.get(f"/api/v1/shop/go/{ASIN_1}", params={"post": pid})
    assert r.status_code == 302, r.text
    loc = r.headers["location"]
    assert loc == _provider.build_affiliate_url(ASIN_1)
    assert "tag=topitems0c1-20" in loc

    async with SessionLocal() as db:
        clicks = (await db.execute(select(ShopClick).where(
            ShopClick.asin == ASIN_1))).scalars().all()
    assert len(clicks) == 1
    assert clicks[0].user_id is None  # anonymous
    assert clicks[0].post_id == uuid.UUID(pid)
    assert len(clicks[0].ip_hash) == 64
    # Anonymous (non-owner) click pays the owner 3 cents cash.
    assert await _click_balance(user) == 3


async def test_go_unknown_asin_404(client):
    r = await client.get("/api/v1/shop/go/B000009999")
    assert r.status_code == 404, r.text
    r = await client.get("/api/v1/shop/go/not-an-asin")
    assert r.status_code == 404, r.text


async def test_self_click_pays_zero(client, user):
    """Owner clicking their own post's product: logged, but no points."""
    cid = await _make_campaign(user)
    await _make_product(ASIN_1, user)
    r = await _opt_in(client, user, str(cid), [ASIN_1])
    pid = r.json()["placement_id"]

    r = await client.get(f"/api/v1/shop/go/{ASIN_1}", params={"post": pid},
                         headers=_auth(user))
    assert r.status_code == 302, r.text
    async with SessionLocal() as db:
        click = (await db.execute(select(ShopClick).where(
            ShopClick.asin == ASIN_1,
            ShopClick.user_id == user))).scalar_one()
    assert click.post_id == uuid.UUID(pid)
    assert await _click_balance(user) == 0


async def test_click_cap_51st_pays_zero(client, user):
    """50 clicks/day pay the owner (3 cents each); the 51st distinct clicker
    still redirects + logs but pays 0."""
    cid = await _make_campaign(user)
    await _make_product(ASIN_1, user)
    r = await _opt_in(client, user, str(cid), [ASIN_1])
    pid = r.json()["placement_id"]

    clicker_ids = []
    async with SessionLocal() as db:
        for i in range(51):
            u = User(email=f"clk{i}_{uuid.uuid4().hex[:6]}@test.com",
                     name="Clicker")
            db.add(u)
            await db.commit()
            await db.refresh(u)
            clicker_ids.append(u.id)

    for kid in clicker_ids:
        r = await client.get(f"/api/v1/shop/go/{ASIN_1}",
                             params={"post": pid}, headers=_auth(kid))
        assert r.status_code == 302, r.text

    assert await _click_balance(user) == 150  # 50 x 3 cents


# ---------------------------------------------------------------- feed
async def test_feed_enriches_tagged_products(client, user):
    """get_feed returns placement_id + tagged_products product cards."""
    cid = await _make_campaign(user, live=True)
    await _make_product(ASIN_1, user)
    async with SessionLocal() as db:
        viewer = User(email=f"viewer_{uuid.uuid4().hex[:8]}@test.com",
                      name="Viewer")
        db.add(viewer)
        await db.commit()
        await db.refresh(viewer)
        pl = DiscoveryPlacement(campaign_id=cid, status="approved",
                                topics=["technology"])
        db.add(pl)
        await db.commit()
        await db.refresh(pl)
        db.add(PostProduct(post_id=pl.id, asin=ASIN_1))
        await db.commit()
        pid = pl.id

        items = await get_feed(db, viewer, limit=20)
    mine = [i for i in items if i["campaign_id"] == str(cid)]
    assert len(mine) == 1
    item = mine[0]
    assert item["placement_id"] == str(pid)
    tp = item["tagged_products"]
    assert len(tp) == 1
    card = tp[0]
    assert card["asin"] == ASIN_1
    assert card["title"] == f"Test product {ASIN_1}"
    assert card["image_url"] == "https://example.com/img1.jpg"
    assert card["price_cents"] == 1299
    assert card["currency"] == "USD"
    assert card["price_display"] == "$12.99"
    assert card["is_affiliate"] is True


async def test_mine_lists_tagged_products(client, user):
    cid = await _make_campaign(user)
    await _make_product(ASIN_1, user)
    await _make_product(ASIN_2, user)
    r = await _opt_in(client, user, str(cid), [ASIN_1, ASIN_2])
    assert r.status_code == 201, r.text
    pid = r.json()["placement_id"]

    r = await client.get("/api/v1/discovery/placements/mine",
                         headers=_auth(user))
    assert r.status_code == 200, r.text
    items = [p for p in r.json()["placements"]
             if p["placement_id"] == pid]
    assert len(items) == 1
    asins = sorted(c["asin"] for c in items[0]["tagged_products"])
    assert asins == [ASIN_1, ASIN_2]
    assert all(c["is_affiliate"] for c in items[0]["tagged_products"])


# ---------------------------------------------------------------- admin
async def test_admin_clicks_report(client, user, admin_user):
    # Fresh ASINs: per_asin totals are global, so scope this test to its
    # own products to keep counts exact.
    asin_a, asin_b = "B000000007", "B000000008"
    cid = await _make_campaign(user)
    await _make_product(asin_a, user)
    await _make_product(asin_b, user)
    r = await _opt_in(client, user, str(cid), [asin_a, asin_b])
    assert r.status_code == 201, r.text
    pid = r.json()["placement_id"]

    for _ in range(3):
        await client.get(f"/api/v1/shop/go/{asin_a}", params={"post": pid})
    await client.get(f"/api/v1/shop/go/{asin_b}", params={"post": pid})

    # Non-admin is rejected.
    r = await client.get("/api/v1/admin/shop/clicks", headers=_auth(user))
    assert r.status_code == 403, r.text

    r = await client.get("/api/v1/admin/shop/clicks",
                         headers=_auth(admin_user))
    assert r.status_code == 200, r.text
    body = r.json()
    per = {row["asin"]: row for row in body["per_asin"]}
    assert per[asin_a]["clicks"] == 3
    assert per[asin_a]["title"] == f"Test product {asin_a}"
    assert per[asin_b]["clicks"] == 1
    posts = [row for row in body["top_posts"] if row["post_id"] == pid]
    assert len(posts) == 1
    assert posts[0]["clicks"] == 4
    assert posts[0]["campaign_title"] == "Shoppable test post"
    assert posts[0]["owner"]  # owner's name/email
