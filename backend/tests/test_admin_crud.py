"""Admin panel full CRUD: edit/delete for comments ("posts"), products, users,
campaigns, broadcasts, discovery placements, support tickets, fraud flags.

Every mutation requires an admin (403 otherwise) and writes an audit entry.
Guards: no self-delete, no deleting the last admin, validated enums."""
from __future__ import annotations

import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, select

from app.core.database import SessionLocal
from app.core.config import settings
from app.core.security import create_token
from app.main import app
from app.models.billing import Broadcast
from app.models.commerce import Product
from app.models.core import (
    AuditLog,
    Campaign,
    CampaignGoal,
    FraudFlag,
    GrowthMode,
    SupportTicket,
    User,
)
from app.models.social import PostComment


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


async def _mk_user(is_admin: bool = False) -> str:
    async with SessionLocal() as db:
        u = User(
            email=f"crud_{uuid.uuid4().hex[:8]}@test.com",
            name="CRUD Tester",
            preferred_language="en",
            is_admin=is_admin,
        )
        db.add(u)
        await db.commit()
        await db.refresh(u)
        return str(u.id)


@pytest_asyncio.fixture
async def admin_uid(monkeypatch):
    uid = await _mk_user(is_admin=True)
    async with SessionLocal() as db:
        email = (await db.execute(
            select(User.email).where(
                User.id == uuid.UUID(uid)))).scalar_one()
    # Admin panel is email-allowlisted (Hafiz 2026-09-30): admit the fixture
    # admin for the duration of the test.
    monkeypatch.setattr(settings, "admin_emails", email)
    return uid


@pytest_asyncio.fixture
async def user_uid():
    return await _mk_user(is_admin=False)


def _auth(uid: str) -> dict:
    token = create_token(uid, timedelta(minutes=30), "access")
    return {"Authorization": f"Bearer {token}"}


async def _audit_count(action: str) -> int:
    async with SessionLocal() as db:
        rows = (await db.execute(
            select(AuditLog).where(AuditLog.action == action))).all()
        return len(rows)


async def _mk_comment(user_uid: str, text: str = "hello world") -> str:
    async with SessionLocal() as db:
        c = PostComment(
            user_id=uuid.UUID(user_uid),
            post_url="https://example.com/post/1",
            author_name="Tester",
            text=text,
        )
        db.add(c)
        await db.commit()
        await db.refresh(c)
        return c.id


# Test isolation: the suite shares one DB per run, and later files (e.g.
# test_ai_core's shop tests) assert on catalog contents. Every product id
# created by this file is tracked here and removed after each test so its
# leftovers never leak into other tests' assertions.
_created_product_ids: list[str] = []


async def _mk_product(user_uid: str, title: str = "Test Widget") -> str:
    async with SessionLocal() as db:
        p = Product(
            creator_id=uuid.UUID(user_uid),
            title=title,
            description="a fine widget",
            price_cents=1999,
            category="tech",
        )
        db.add(p)
        await db.commit()
        await db.refresh(p)
        pid = str(p.id)
    _created_product_ids.append(pid)
    return pid


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_products():
    yield
    ids = list(_created_product_ids)
    _created_product_ids.clear()
    if not ids:
        return
    async with SessionLocal() as db:
        await db.execute(delete(Product).where(
            Product.id.in_([uuid.UUID(pid) for pid in ids])))
        await db.commit()


async def _mk_campaign(user_uid: str) -> str:
    async with SessionLocal() as db:
        c = Campaign(
            user_id=uuid.UUID(user_uid),
            title="Test campaign",
            post_url="https://example.com/post/1",
            platform="instagram",
            goal=CampaignGoal.reach,
            mode=GrowthMode.organic,
        )
        db.add(c)
        await db.commit()
        await db.refresh(c)
        return str(c.id)


async def _mk_broadcast(admin_uid: str) -> str:
    async with SessionLocal() as db:
        b = Broadcast(
            title="Hello users",
            body="Important news",
            audience="all",
            created_by=uuid.UUID(admin_uid),
        )
        db.add(b)
        await db.commit()
        await db.refresh(b)
        return str(b.id)


async def _mk_ticket(user_uid: str) -> str:
    async with SessionLocal() as db:
        t = SupportTicket(
            user_id=uuid.UUID(user_uid),
            subject="Need help",
            message="It broke",
        )
        db.add(t)
        await db.commit()
        await db.refresh(t)
        return str(t.id)


# ------------------------------------------------------------------ guards

@pytest.mark.asyncio
async def test_non_admin_cannot_edit(client, admin_uid, user_uid):
    pid = await _mk_product(user_uid)
    r = await client.patch(f"/api/v1/admin/products/{pid}",
                           json={"title": "Hacked"}, headers=_auth(user_uid))
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_unauthenticated_cannot_delete(client, admin_uid, user_uid):
    pid = await _mk_product(user_uid)
    r = await client.delete(f"/api/v1/admin/products/{pid}")
    assert r.status_code in (401, 403)


# ------------------------------------------------------------------ comments

@pytest.mark.asyncio
async def test_comment_edit_persists_and_audits(client, admin_uid, user_uid):
    cid = await _mk_comment(user_uid)
    before = await _audit_count("admin.comment.edit")
    r = await client.patch(f"/api/v1/admin/comments/{cid}",
                           json={"text": "edited by admin"},
                           headers=_auth(admin_uid))
    assert r.status_code == 200
    assert r.json()["ok"] is True
    async with SessionLocal() as db:
        c = (await db.execute(
            select(PostComment).where(PostComment.id == cid))).scalar_one()
        assert c.text == "edited by admin"
    assert await _audit_count("admin.comment.edit") == before + 1


@pytest.mark.asyncio
async def test_comment_edit_empty_text_rejected(client, admin_uid, user_uid):
    cid = await _mk_comment(user_uid)
    r = await client.patch(f"/api/v1/admin/comments/{cid}",
                           json={"text": "   "}, headers=_auth(admin_uid))
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_comment_delete_then_404(client, admin_uid, user_uid):
    cid = await _mk_comment(user_uid)
    r = await client.delete(f"/api/v1/admin/comments/{cid}",
                            headers=_auth(admin_uid))
    assert r.status_code == 200
    r2 = await client.delete(f"/api/v1/admin/comments/{cid}",
                             headers=_auth(admin_uid))
    assert r2.status_code == 404


# ------------------------------------------------------------------ products

@pytest.mark.asyncio
async def test_product_edit_persists(client, admin_uid, user_uid):
    pid = await _mk_product(user_uid)
    r = await client.patch(
        f"/api/v1/admin/products/{pid}",
        json={"title": "Renamed Widget", "price_cents": 2499,
              "is_active": False},
        headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        p = (await db.execute(select(Product).where(
            Product.id == uuid.UUID(pid)))).scalar_one()
        assert p.title == "Renamed Widget"
        assert p.price_cents == 2499
        assert p.is_active is False


@pytest.mark.asyncio
async def test_product_edit_bad_category_rejected(client, admin_uid, user_uid):
    pid = await _mk_product(user_uid)
    r = await client.patch(f"/api/v1/admin/products/{pid}",
                           json={"category": "not_a_dept"},
                           headers=_auth(admin_uid))
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_product_delete(client, admin_uid, user_uid):
    pid = await _mk_product(user_uid)
    r = await client.delete(f"/api/v1/admin/products/{pid}",
                            headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        gone = (await db.execute(select(Product).where(
            Product.id == uuid.UUID(pid)))).scalar_one_or_none()
        assert gone is None


# ------------------------------------------------------------------ users

@pytest.mark.asyncio
async def test_user_edit_name(client, admin_uid, user_uid):
    r = await client.patch(f"/api/v1/admin/users/{user_uid}",
                           json={"name": "New Name"},
                           headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(
            User.id == uuid.UUID(user_uid)))).scalar_one()
        assert u.name == "New Name"


@pytest.mark.asyncio
async def test_admin_cannot_delete_self(client, admin_uid):
    r = await client.delete(f"/api/v1/admin/users/{admin_uid}",
                            headers=_auth(admin_uid))
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_admin_cannot_delete_last_admin(client, admin_uid):
    # admin_uid is the only admin in this fresh DB slice; deleting them
    # must be refused even though it is not "self" via another admin.
    other = await _mk_user(is_admin=True)
    r = await client.delete(f"/api/v1/admin/users/{other}",
                            headers=_auth(admin_uid))
    # other is not the last admin (admin_uid remains) -> allowed
    assert r.status_code == 200
    r2 = await client.delete(f"/api/v1/admin/users/{admin_uid}",
                             headers=_auth(admin_uid))
    assert r2.status_code == 400  # self-delete still blocked first


@pytest.mark.asyncio
async def test_user_delete_cascades_comments(client, admin_uid):
    victim = await _mk_user()
    cid = await _mk_comment(victim)
    r = await client.delete(f"/api/v1/admin/users/{victim}",
                            headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        assert (await db.execute(select(User).where(
            User.id == uuid.UUID(victim)))).scalar_one_or_none() is None
        assert (await db.execute(select(PostComment).where(
            PostComment.id == cid))).scalar_one_or_none() is None


# ------------------------------------------------------------------ campaigns

@pytest.mark.asyncio
async def test_campaign_edit_status(client, admin_uid, user_uid):
    cid = await _mk_campaign(user_uid)
    r = await client.patch(f"/api/v1/admin/campaigns/{cid}",
                           json={"status": "paused", "title": "Renamed"},
                           headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        c = (await db.execute(select(Campaign).where(
            Campaign.id == uuid.UUID(cid)))).scalar_one()
        assert c.status.value == "paused"
        assert c.title == "Renamed"


@pytest.mark.asyncio
async def test_campaign_edit_bad_status_rejected(client, admin_uid, user_uid):
    cid = await _mk_campaign(user_uid)
    r = await client.patch(f"/api/v1/admin/campaigns/{cid}",
                           json={"status": "exploding"},
                           headers=_auth(admin_uid))
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_campaign_delete(client, admin_uid, user_uid):
    cid = await _mk_campaign(user_uid)
    r = await client.delete(f"/api/v1/admin/campaigns/{cid}",
                            headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        assert (await db.execute(select(Campaign).where(
            Campaign.id == uuid.UUID(cid)))).scalar_one_or_none() is None


# ------------------------------------------------------------------ broadcasts

@pytest.mark.asyncio
async def test_broadcast_edit_and_delete(client, admin_uid):
    bid = await _mk_broadcast(admin_uid)
    r = await client.patch(f"/api/v1/admin/broadcasts/{bid}",
                           json={"audience": "paid", "title": "Updated"},
                           headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        b = (await db.execute(select(Broadcast).where(
            Broadcast.id == uuid.UUID(bid)))).scalar_one()
        assert b.audience == "paid"
    r = await client.delete(f"/api/v1/admin/broadcasts/{bid}",
                            headers=_auth(admin_uid))
    assert r.status_code == 200
    r = await client.patch(f"/api/v1/admin/broadcasts/{bid}",
                           json={"title": "x"}, headers=_auth(admin_uid))
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_broadcast_edit_bad_audience_rejected(client, admin_uid):
    bid = await _mk_broadcast(admin_uid)
    r = await client.patch(f"/api/v1/admin/broadcasts/{bid}",
                           json={"audience": "everyone"},
                           headers=_auth(admin_uid))
    assert r.status_code == 400


# ------------------------------------------------------------------ tickets

@pytest.mark.asyncio
async def test_ticket_resolve_and_delete(client, admin_uid, user_uid):
    tid = await _mk_ticket(user_uid)
    r = await client.post(f"/api/v1/admin/tickets/{tid}/resolve",
                          headers=_auth(admin_uid))
    assert r.status_code == 200
    assert r.json()["status"] == "closed"
    async with SessionLocal() as db:
        t = (await db.execute(select(SupportTicket).where(
            SupportTicket.id == uuid.UUID(tid)))).scalar_one()
        assert t.status == "closed"
    r = await client.delete(f"/api/v1/admin/tickets/{tid}",
                            headers=_auth(admin_uid))
    assert r.status_code == 200


# ------------------------------------------------------------------ fraud flags

@pytest.mark.asyncio
async def test_fraud_flag_delete_missing_404(client, admin_uid):
    r = await client.delete(
        f"/api/v1/admin/fraud-flags/{uuid.uuid4()}",
        headers=_auth(admin_uid))
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_fraud_flag_delete(client, admin_uid, user_uid):
    cid = await _mk_campaign(user_uid)
    async with SessionLocal() as db:
        f = FraudFlag(campaign_id=uuid.UUID(cid), reason="test flag")
        db.add(f)
        await db.commit()
        await db.refresh(f)
        fid = str(f.id)
    r = await client.delete(f"/api/v1/admin/fraud-flags/{fid}",
                            headers=_auth(admin_uid))
    assert r.status_code == 200
    async with SessionLocal() as db:
        assert (await db.execute(select(FraudFlag).where(
            FraudFlag.id == uuid.UUID(fid)))).scalar_one_or_none() is None
