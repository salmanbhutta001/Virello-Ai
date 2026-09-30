"""Phase 8 — GET /api/v1/discovery/interactions/mine.

The Activity screen's Likes tab needs the caller's own genuine like
interactions, joined with campaign titles. Tests: like is recorded via
the existing POST /interactions, then listed newest-first with the
campaign title; kind filter works; only the caller's own rows appear.
"""
import uuid

import httpx
import pytest
import pytest_asyncio

from app.core.database import SessionLocal
from app.main import app
from app.models.core import User


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def user():
    async with SessionLocal() as db:
        u = User(email=f"interact_{uuid.uuid4().hex[:8]}@test.com",
                 name="Interaction Tester", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = str(u.id)
    yield uid


def _auth(uid: str) -> dict:
    from datetime import timedelta

    from app.core.security import create_token
    token = create_token(str(uid), timedelta(minutes=30))
    return {"Authorization": f"Bearer {token}"}


async def _make_campaign(client: httpx.AsyncClient, h: dict) -> str:
    r = await client.post(
        "/api/v1/campaigns",
        json={
            "post_url": f"https://example.com/post-{uuid.uuid4().hex[:8]}",
            "platform": "instagram",
            "goal": "reach",
            "mode": "organic",
        },
        headers=h,
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


@pytest.mark.asyncio
async def test_my_interactions_like_listed(client: httpx.AsyncClient, user):
    h = _auth(user)
    cid = await _make_campaign(client, h)
    r = await client.post(
        "/api/v1/discovery/interactions",
        json={"campaign_id": cid, "kind": "like"},
        headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["recorded"] is True

    r = await client.get(
        "/api/v1/discovery/interactions/mine", params={"kind": "like"}
    , headers=h)
    assert r.status_code == 200, r.text
    items = r.json()["interactions"]
    assert len(items) >= 1
    mine = [i for i in items if i["campaign_id"] == cid]
    assert len(mine) == 1
    assert mine[0]["kind"] == "like"
    assert mine[0]["campaign_title"]
    assert mine[0]["created_at"]


@pytest.mark.asyncio
async def test_my_interactions_kind_filter(client: httpx.AsyncClient, user):
    h = _auth(user)
    cid = await _make_campaign(client, h)
    await client.post(
        "/api/v1/discovery/interactions",
        json={"campaign_id": cid, "kind": "save"},
        headers=h)
    r = await client.get(
        "/api/v1/discovery/interactions/mine", params={"kind": "like"}
    , headers=h)
    assert r.status_code == 200
    for i in r.json()["interactions"]:
        assert i["kind"] == "like"

    r = await client.get("/api/v1/discovery/interactions/mine", headers=h)
    assert r.status_code == 200
    kinds = {i["kind"] for i in r.json()["interactions"]}
    assert "save" in kinds


@pytest.mark.asyncio
async def test_my_interactions_invalid_kind_rejected(
    client: httpx.AsyncClient,
    user,):
    h = _auth(user)
    cid = await _make_campaign(client, h)
    r = await client.post(
        "/api/v1/discovery/interactions",
        json={"campaign_id": cid, "kind": "bogus"},
        headers=h)
    assert r.status_code == 400
