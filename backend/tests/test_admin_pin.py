"""PIN-gated admin unlock: server-side elevation, audit trail, 403/429
behaviour, and the hard rule that the PIN value never appears in logs."""
from __future__ import annotations

import logging
import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import clear_login_attempts, create_token
from app.main import app
from app.models.core import AuditLog, User

TEST_PIN = "0000"


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def user():
    async with SessionLocal() as db:
        u = User(
            email=f"pin_{uuid.uuid4().hex[:8]}@test.com",
            name="Pin Tester",
            preferred_language="en",
        )
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = str(u.id)
    # fresh throttle bucket for every test user
    clear_login_attempts(f"admin_pin:{uid}")
    yield uid


@pytest.fixture
def pin_env(monkeypatch):
    monkeypatch.setattr(settings, "admin_pin", TEST_PIN)


def _auth(uid: str) -> dict:
    token = create_token(uid, timedelta(minutes=30), "access")
    return {"Authorization": f"Bearer {token}"}


async def _is_admin(uid: str) -> bool:
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == uuid.UUID(uid)))).scalar_one()
        return bool(u.is_admin)


async def _audit_count(uid: str, action: str) -> int:
    async with SessionLocal() as db:
        rows = (await db.execute(
            select(AuditLog).where(AuditLog.user_id == uuid.UUID(uid),
                                  AuditLog.action == action)
        )).all()
        return len(rows)


# ---------------------------------------------------------------------------
# 1. Correct PIN elevates server-side + audit entry written
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_correct_pin_elevates_and_audits(client, user, pin_env):
    assert not await _is_admin(user)
    r = await client.post("/api/v1/admin/unlock", json={"pin": TEST_PIN},
                          headers=_auth(user))
    assert r.status_code == 200
    assert r.json() == {"ok": True, "is_admin": True}
    assert await _is_admin(user)
    assert await _audit_count(user, "admin.pin.unlock") == 1


# ---------------------------------------------------------------------------
# 2. Wrong PIN -> 403, no elevation, no audit entry
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_wrong_pin_403_no_elevation(client, user, pin_env):
    r = await client.post("/api/v1/admin/unlock", json={"pin": "9999"},
                          headers=_auth(user))
    assert r.status_code == 403
    assert not await _is_admin(user)
    assert await _audit_count(user, "admin.pin.unlock") == 0


# ---------------------------------------------------------------------------
# 3. Unauthenticated -> 401
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_unlock_requires_auth(client, pin_env):
    r = await client.post("/api/v1/admin/unlock", json={"pin": TEST_PIN})
    assert r.status_code == 401


# ---------------------------------------------------------------------------
# 4. Throttle: 5 wrong attempts per 15 min -> 429 on the 6th
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_pin_throttle_after_five_failures(client, user, pin_env):
    for _ in range(5):
        r = await client.post("/api/v1/admin/unlock", json={"pin": "9999"},
                              headers=_auth(user))
        assert r.status_code == 403
    r = await client.post("/api/v1/admin/unlock", json={"pin": "9999"},
                          headers=_auth(user))
    assert r.status_code == 429
    assert not await _is_admin(user)


# ---------------------------------------------------------------------------
# 5. The PIN value never appears in logs (wrong or right attempt)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_pin_never_in_logs(client, user, pin_env, caplog):
    secret_wrong = "s3cr3t-pin-xyz-123"
    with caplog.at_level(logging.INFO):
        await client.post("/api/v1/admin/unlock", json={"pin": secret_wrong},
                          headers=_auth(user))
        await client.post("/api/v1/admin/unlock", json={"pin": TEST_PIN},
                          headers=_auth(user))
    for record in caplog.records:
        msg = record.getMessage()
        assert secret_wrong not in msg
        assert TEST_PIN not in msg
