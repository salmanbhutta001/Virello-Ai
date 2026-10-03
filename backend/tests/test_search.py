"""Search endpoints: GET /api/v1/discovery/search and GET /api/v1/users/search.

Verifies real matches return and gibberish returns empty — never fake results.
"""
import uuid

import httpx
import pytest
import pytest_asyncio

from app.core.database import SessionLocal
from app.core.security import create_token
from app.main import app
from app.models.core import (
    Campaign,
    CampaignGoal,
    CampaignStatus,
    GrowthMode,
    User,
)
from app.models.growth import DiscoveryPlacement


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def auth_headers():
    async with SessionLocal() as db:
        u = User(
            email=f"searcher_{uuid.uuid4().hex[:8]}@test.com",
            name="Search Tester",
            preferred_language="en",
        )
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
        token = create_token(uid)
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def searchable_post(auth_headers):
    async with SessionLocal() as db:
        u = User(
            email=f"poster_{uuid.uuid4().hex[:8]}@test.com",
            name="Post Owner",
            preferred_language="en",
        )
        db.add(u)
        await db.flush()
        c = Campaign(
            id=uuid.uuid4(),
            user_id=u.id,
            title="Amazing Mango Smoothie Recipe for Summer",
            post_url="https://example.com/mango-smoothie",
            platform="instagram",
            goal=CampaignGoal.engagement,
            mode=GrowthMode.organic,
            status=CampaignStatus.live,
        )
        db.add(c)
        await db.flush()
        p = DiscoveryPlacement(
            id=uuid.uuid4(),
            campaign_id=c.id,
            topics=["food_recipes", "health"],
            status="approved",
        )
        db.add(p)
        await db.commit()


@pytest_asyncio.fixture
async def searchable_user(auth_headers):
    async with SessionLocal() as db:
        u = User(
            email=f"chef_{uuid.uuid4().hex[:8]}@test.com",
            name="Mango Chef Maria",
            preferred_language="en",
        )
        db.add(u)
        await db.commit()


class TestDiscoverySearch:
    async def test_finds_post_by_title_word(
        self, client, searchable_post, auth_headers
    ):
        r = await client.get(
            "/api/v1/discovery/search",
            params={"q": "mango"},
            headers=auth_headers,
        )
        assert r.status_code == 200
        data = r.json()
        assert data["total"] >= 1
        assert any("Mango" in i["title"] for i in data["items"])

    async def test_case_insensitive(
        self, client, searchable_post, auth_headers
    ):
        r = await client.get(
            "/api/v1/discovery/search",
            params={"q": "MANGO"},
            headers=auth_headers,
        )
        assert r.status_code == 200
        assert r.json()["total"] >= 1

    async def test_matches_topic(
        self, client, searchable_post, auth_headers
    ):
        r = await client.get(
            "/api/v1/discovery/search",
            params={"q": "food_recipes"},
            headers=auth_headers,
        )
        assert r.status_code == 200
        assert r.json()["total"] >= 1

    async def test_gibberish_returns_empty(
        self, client, searchable_post, auth_headers
    ):
        r = await client.get(
            "/api/v1/discovery/search",
            params={"q": "xqzvkqwvzx"},
            headers=auth_headers,
        )
        assert r.status_code == 200
        data = r.json()
        assert data["total"] == 0
        assert data["items"] == []

    async def test_empty_query_returns_empty(self, client, auth_headers):
        r = await client.get("/api/v1/discovery/search", headers=auth_headers)
        assert r.status_code == 200
        assert r.json()["items"] == []

    async def test_requires_auth(self, client):
        r = await client.get("/api/v1/discovery/search", params={"q": "mango"})
        assert r.status_code in (401, 403)


class TestUsersSearch:
    async def test_finds_user_by_name(
        self, client, searchable_user, auth_headers
    ):
        r = await client.get(
            "/api/v1/users/search",
            params={"q": "maria"},
            headers=auth_headers,
        )
        assert r.status_code == 200
        data = r.json()
        assert data["total"] >= 1
        assert any("Maria" in u["name"] for u in data["users"])

    async def test_gibberish_returns_empty(
        self, client, searchable_user, auth_headers
    ):
        r = await client.get(
            "/api/v1/users/search",
            params={"q": "xqzvkqwvzx"},
            headers=auth_headers,
        )
        assert r.status_code == 200
        assert r.json()["users"] == []

    async def test_requires_auth(self, client):
        r = await client.get("/api/v1/users/search", params={"q": "maria"})
        assert r.status_code in (401, 403)
