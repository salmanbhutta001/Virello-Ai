"""POST /api/v1/ads/ad-copy — heuristic ad copy variants for the AI Ad Builder.

Stateless: no DB writes. Must always return 3 variants (headline/text/cta),
never invent stats or guarantees, and respect the requested language.
"""
import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio

from app.core.database import SessionLocal
from app.core.security import create_token
from app.main import app
from app.models.core import User
from app.services import ad_copy


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
            email=f"adcopy_{uuid.uuid4().hex[:8]}@test.com",
            name="AdCopy Tester",
            preferred_language="en",
        )
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    token = create_token(str(uid), timedelta(minutes=30), "access")
    return {"Authorization": f"Bearer {token}"}


def test_generator_always_returns_three_variants():
    for lang in ("en", "ur", "ar"):
        out = ad_copy.generate_ad_copy_variants(
            content="Fresh homemade biryani recipe! Easy steps for dinner. #FoodRecipes",
            topics=["Food & Recipes"],
            language=lang,
        )
        assert out["language"] == lang
        assert len(out["variants"]) == 3
        for v in out["variants"]:
            assert v["headline"].strip()
            assert v["text"].strip()
            assert v["cta"].strip()


def test_generator_never_invents_claims():
    out = ad_copy.generate_ad_copy_variants(
        content="Selling my old bike", topics=["Automobiles"], language="en")
    blob = " ".join(v["headline"] + " " + v["text"] + " " + v["cta"]
                    for v in out["variants"]).lower()
    for banned in ("guaranteed", "viral", "10x", "%", "proven", "billion"):
        assert banned not in blob


def test_generator_empty_input_still_returns_three():
    out = ad_copy.generate_ad_copy_variants(content="", topics=[], language="en")
    assert len(out["variants"]) == 3
    assert all(v["headline"] for v in out["variants"])


@pytest.mark.asyncio
async def test_endpoint_requires_auth(client):
    r = await client.post("/api/v1/ads/ad-copy", json={"content": "hi"})
    assert r.status_code in (401, 403)


@pytest.mark.asyncio
async def test_endpoint_returns_variants(client, auth_headers):
    r = await client.post(
        "/api/v1/ads/ad-copy",
        headers=auth_headers,
        json={
            "content": "New fitness challenge starting Monday! Join my 30-day plan.",
            "topics": ["Fitness"],
            "language": "en",
        },
    )
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["language"] == "en"
    assert len(j["variants"]) == 3
    assert all(set(v) >= {"headline", "text", "cta"} for v in j["variants"])


@pytest.mark.asyncio
async def test_endpoint_ur_language(client, auth_headers):
    r = await client.post(
        "/api/v1/ads/ad-copy",
        headers=auth_headers,
        json={"content": "Meri nayi recipe video dekhein!", "language": "ur"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["language"] == "ur"
