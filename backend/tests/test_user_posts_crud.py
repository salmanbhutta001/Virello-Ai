"""User-side edit/delete for OWN posts and campaigns.

Posts = DiscoveryPlacement rows (a campaign shared to the discovery feed).
Every mutation is owner-only: non-owners get 404 (never 403, so ownership
does not leak). Deleting a post cascades its product tags + tracked
clicks and reverses the points paid for creating it. Campaign PATCH edits
title/goal/budget; campaign DELETE already existed.
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
from app.models.commerce import PostProduct, ShopClick
from app.models.core import Campaign, CampaignGoal, CampaignStatus, GrowthMode, User
from app.models.growth import DiscoveryPlacement
from app.models.rewards import PointsLedger


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def owner():
    async with SessionLocal() as db:
        u = User(email=f"own_{uuid.uuid4().hex[:8]}@test.com",
                 name="Owner", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    yield uid


@pytest_asyncio.fixture
async def stranger():
    async with SessionLocal() as db:
        u = User(email=f"str_{uuid.uuid4().hex[:8]}@test.com",
                 name="Stranger", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    yield uid


def _auth(uid) -> dict:
    return {"Authorization": f"Bearer {create_token(str(uid), timedelta(minutes=30))}"}


async def _campaign(uid) -> uuid.UUID:
    async with SessionLocal() as db:
        c = Campaign(user_id=uid, title="My test post",
                     post_url=f"https://example.com/p-{uuid.uuid4().hex[:8]}",
                     platform="instagram", goal=CampaignGoal.reach,
                     mode=GrowthMode.organic)
        db.add(c)
        await db.commit()
        await db.refresh(c)
        return c.id


async def _post(client, uid, campaign_id) -> str:
    r = await client.post("/api/v1/discovery/placements",
                          json={"campaign_id": str(campaign_id),
                                "topics": ["technology"]},
                          headers=_auth(uid))
    assert r.status_code == 201, r.text
    return r.json()["placement_id"]


async def _points_balance(uid) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(PointsLedger.delta), 0))
            .where(PointsLedger.user_id == uid))).scalar() or 0


# ------------------------------------------------------------ post edit
async def test_edit_own_post_topics(client, owner):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    r = await client.patch(f"/api/v1/posts/{pid}",
                           json={"topics": ["fashion", "beauty"]},
                           headers=_auth(owner))
    assert r.status_code == 200, r.text
    assert r.json()["topics"] == ["fashion", "beauty"]


async def test_edit_post_empty_topics_400(client, owner):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    r = await client.patch(f"/api/v1/posts/{pid}", json={"topics": []},
                           headers=_auth(owner))
    assert r.status_code == 400


async def test_edit_post_too_many_topics_400(client, owner):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    r = await client.patch(
        f"/api/v1/posts/{pid}",
        json={"topics": ["a", "b", "c", "d", "e", "f"]},
        headers=_auth(owner))
    assert r.status_code == 400


async def test_edit_post_non_owner_404(client, owner, stranger):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    r = await client.patch(f"/api/v1/posts/{pid}",
                           json={"topics": ["fashion"]},
                           headers=_auth(stranger))
    assert r.status_code == 404


async def test_edit_rejected_post_resubmits(client, owner):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    async with SessionLocal() as db:
        p = (await db.execute(select(DiscoveryPlacement).where(
            DiscoveryPlacement.id == uuid.UUID(pid)))).scalar_one()
        p.status = "rejected"
        p.review_note = "spam?"
        await db.commit()
    r = await client.patch(f"/api/v1/posts/{pid}",
                           json={"topics": ["technology"]},
                           headers=_auth(owner))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "pending"
    assert body["resubmitted"] is True


# ---------------------------------------------------------- post delete
async def test_delete_own_post_cascades(client, owner):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    async with SessionLocal() as db:
        db.add(PostProduct(post_id=uuid.UUID(pid), asin="B000000001"))
        db.add(ShopClick(post_id=uuid.UUID(pid), asin="B000000001",
                         ip_hash="x" * 64))
        await db.commit()
    r = await client.delete(f"/api/v1/posts/{pid}", headers=_auth(owner))
    assert r.status_code == 200, r.text
    async with SessionLocal() as db:
        assert (await db.execute(select(DiscoveryPlacement).where(
            DiscoveryPlacement.id == uuid.UUID(pid)))).scalar_one_or_none() is None
        assert (await db.execute(select(PostProduct).where(
            PostProduct.post_id == uuid.UUID(pid)))).scalars().all() == []
        assert (await db.execute(select(ShopClick).where(
            ShopClick.post_id == uuid.UUID(pid)))).scalars().all() == []
        # the campaign itself survives a post delete
        assert (await db.execute(select(Campaign).where(
            Campaign.id == cid))).scalar_one_or_none() is not None


async def test_delete_post_reverses_points(client, owner):
    before = await _points_balance(owner)
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)  # awards post_created points
    earned = await _points_balance(owner)
    assert earned > before
    r = await client.delete(f"/api/v1/posts/{pid}", headers=_auth(owner))
    assert r.status_code == 200, r.text
    assert r.json()["points_reversed"] > 0
    assert await _points_balance(owner) == before


async def test_delete_post_non_owner_404(client, owner, stranger):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    r = await client.delete(f"/api/v1/posts/{pid}", headers=_auth(stranger))
    assert r.status_code == 404
    async with SessionLocal() as db:
        assert (await db.execute(select(DiscoveryPlacement).where(
            DiscoveryPlacement.id == uuid.UUID(pid)))).scalar_one_or_none() is not None


async def test_my_posts_lists_own_only(client, owner, stranger):
    cid = await _campaign(owner)
    pid = await _post(client, owner, cid)
    r = await client.get("/api/v1/posts/mine", headers=_auth(owner))
    assert r.status_code == 200
    ids = [p["placement_id"] for p in r.json()["posts"]]
    assert pid in ids
    r2 = await client.get("/api/v1/posts/mine", headers=_auth(stranger))
    assert r2.status_code == 200
    assert r2.json()["posts"] == []


# -------------------------------------------------------- campaign edit
async def test_campaign_owner_edit(client, owner):
    cid = await _campaign(owner)
    r = await client.patch(f"/api/v1/campaigns/{cid}",
                           json={"title": "New title",
                                 "goal": "leads", "budget_usd": 25},
                           headers=_auth(owner))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["title"] == "New title"
    assert body["goal"] == "leads"
    assert body["budget_usd"] == 25


async def test_campaign_edit_non_owner_404(client, owner, stranger):
    cid = await _campaign(owner)
    r = await client.patch(f"/api/v1/campaigns/{cid}",
                           json={"title": "Hijack"},
                           headers=_auth(stranger))
    assert r.status_code == 404


async def test_campaign_edit_negative_budget_400(client, owner):
    cid = await _campaign(owner)
    r = await client.patch(f"/api/v1/campaigns/{cid}",
                           json={"budget_usd": -5},
                           headers=_auth(owner))
    assert r.status_code == 400
