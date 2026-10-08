"""Password signup must never 500 because of the referral subsystem.

Regression test for the 2026-10-08 Huawei AppGallery rejection
("registration module reports an error"): production lacked the
referral_codes / referral_events tables (no Alembic migration ever
created them), and award_referral_credits UPDATEs referral_events on
every password signup -> HTTP 500 for every new registration.

The referral helpers are best-effort now: signup succeeds even when
the referral tables are absent.
"""
from __future__ import annotations

import uuid

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import text

from app.core.database import SessionLocal, engine
from app.main import app


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def no_referral_tables():
    """Drop the referral tables to simulate the production state."""
    async with engine.begin() as conn:
        await conn.execute(text("DROP TABLE IF EXISTS referral_events"))
        await conn.execute(text("DROP TABLE IF EXISTS referral_codes"))
    yield
    # Recreate for other tests.
    async with engine.begin() as conn:
        await conn.run_sync(
            lambda c: __import__(
                "app.models.referrals", fromlist=["ReferralCode"]
            ).ReferralCode.__table__.create(c, checkfirst=True)
        )
        await conn.run_sync(
            lambda c: __import__(
                "app.models.referrals", fromlist=["ReferralEvent"]
            ).ReferralEvent.__table__.create(c, checkfirst=True)
        )


async def test_signup_succeeds_without_referral_tables(
    client, no_referral_tables
):
    email = f"sg_{uuid.uuid4().hex[:8]}@test.com"
    r = await client.post(
        "/api/v1/auth/password/signup",
        json={"email": email, "password": "TestPass123!",
              "name": "Signup Resilience"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert "access_token" in body

    # The new account can sign in and read /users/me.
    r = await client.post(
        "/api/v1/auth/password/login",
        json={"email": email, "password": "TestPass123!"},
    )
    assert r.status_code == 200, r.text
    token = r.json()["access_token"]
    r = await client.get(
        "/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert r.status_code == 200, r.text


async def test_signup_succeeds_with_referral_tables(client):
    email = f"sg_{uuid.uuid4().hex[:8]}@test.com"
    r = await client.post(
        "/api/v1/auth/password/signup",
        json={"email": email, "password": "TestPass123!",
              "name": "Signup Normal"},
    )
    assert r.status_code == 200, r.text
    assert "access_token" in r.json()
