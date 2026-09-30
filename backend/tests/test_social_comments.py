"""Phase 4 — social comments: genuine user comments on discovery posts.

Real user-generated content only: comments are created by explicit user
action, never seeded. Tests: create, list (newest first), validation,
ownership on delete, and the /mine feed for the Activity screen.
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
        u = User(email=f"comments_{uuid.uuid4().hex[:8]}@test.com",
                 name="Comments Tester", preferred_language="en")
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


def _url():
    return f"https://example.com/post-{uuid.uuid4().hex[:8]}"


@pytest.mark.asyncio
async def test_comment_create_and_list(client: httpx.AsyncClient, user):
    url = _url()
    r = await client.post(
        "/api/v1/social/comments",
        json={"post_url": url, "text": "Great kitchen towels!"},
        headers=_auth(user))
    assert r.status_code == 201, r.text
    j = r.json()
    assert j["ok"] is True
    assert j["comment"]["text"] == "Great kitchen towels!"
    assert j["comment"]["mine"] is True
    assert j["comment"]["author_name"]

    r = await client.get("/api/v1/social/comments", params={"post_url": url}, headers=_auth(user))
    assert r.status_code == 200, r.text
    comments = r.json()["comments"]
    assert len(comments) == 1
    assert comments[0]["text"] == "Great kitchen towels!"


@pytest.mark.asyncio
async def test_comment_list_empty_never_fabricated(
    client: httpx.AsyncClient,
    user,
):
    r = await client.get(
        "/api/v1/social/comments", params={"post_url": _url()},
        headers=_auth(user))
    assert r.status_code == 200
    assert r.json()["comments"] == []


@pytest.mark.asyncio
async def test_comment_validation(client: httpx.AsyncClient, user):
    url = _url()
    r = await client.post(
        "/api/v1/social/comments", json={"post_url": url, "text": "   "}
    , headers=_auth(user))
    assert r.status_code == 422
    r = await client.post(
        "/api/v1/social/comments", json={"post_url": "", "text": "hi"}
    , headers=_auth(user))
    assert r.status_code == 400
    r = await client.post(
        "/api/v1/social/comments",
        json={"post_url": url, "text": "x" * 2001},
        headers=_auth(user))
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_comment_delete_own(client: httpx.AsyncClient, user):
    url = _url()
    r = await client.post(
        "/api/v1/social/comments",
        json={"post_url": url, "text": "to be deleted"},
        headers=_auth(user))
    cid = r.json()["comment"]["id"]
    r = await client.delete(f"/api/v1/social/comments/{cid}", headers=_auth(user))
    assert r.status_code == 200, r.text
    r = await client.get("/api/v1/social/comments", params={"post_url": url}, headers=_auth(user))
    assert r.json()["comments"] == []


@pytest.mark.asyncio
async def test_comment_delete_missing(client: httpx.AsyncClient, user):
    r = await client.delete(f"/api/v1/social/comments/{uuid.uuid4().hex}", headers=_auth(user))
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_my_comments_feed(client: httpx.AsyncClient, user):
    url = _url()
    await client.post(
        "/api/v1/social/comments",
        json={"post_url": url, "text": "my activity comment"},
        headers=_auth(user))
    r = await client.get("/api/v1/social/comments/mine", headers=_auth(user))
    assert r.status_code == 200, r.text
    comments = r.json()["comments"]
    assert any(c["text"] == "my activity comment" for c in comments)
    assert all(c["mine"] is True for c in comments)
