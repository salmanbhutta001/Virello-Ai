"""Blog engine: seed migration, honesty gates, public API, manual controls."""
from __future__ import annotations

import json

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select

import app.blog.generator as generator
from app.blog.models import BlogPost, BlogRun
from app.blog.seed import seed_blog_posts
from app.core.database import SessionLocal
from app.main import app
from app.services.ai.base import AIResponse, DevMuseProvider


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test") as c:
        yield c


async def _post_count(db) -> int:
    return (await db.execute(
        select(func.count(BlogPost.id)))).scalar() or 0


# ---------------------------------------------------------------------------
# Seed migration
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_seed_migrates_website_articles_once():
    async with SessionLocal() as db:
        before = await _post_count(db)
        created = await seed_blog_posts(db)
        if before == 0:
            assert created == 14
        again = await seed_blog_posts(db)
        assert again == 0
        assert await _post_count(db) >= 14


@pytest.mark.asyncio
async def test_public_list_and_detail(client):
    async with SessionLocal() as db:
        await seed_blog_posts(db)
    r = await client.get("/api/v1/blog/posts?limit=5")
    assert r.status_code == 200
    data = r.json()
    assert data["total"] >= 14
    first = data["posts"][0]
    for key in ("slug", "cat", "title", "mins", "date", "img", "excerpt"):
        assert key in first
    assert "body" not in first  # list stays light
    d = await client.get(f"/api/v1/blog/posts/{first['slug']}")
    assert d.status_code == 200
    assert len(d.json()["body"]) >= 3
    missing = await client.get("/api/v1/blog/posts/no-such-article")
    assert missing.status_code == 404


# ---------------------------------------------------------------------------
# Generator honesty gates
# ---------------------------------------------------------------------------

class _FakeProvider:
    name = "fake"
    model = "fake-1"

    def __init__(self, payload: dict):
        self._payload = payload

    async def complete(self, req):
        return AIResponse(text=json.dumps(self._payload), provider="fake",
                          model="fake-1", dev=False)


def _good_payload(words: int = 1600) -> dict:
    para = " ".join(["creators grow by testing one clear idea at a time"] * 12)
    body = ["<h3>Start with the idea</h3>"]
    n = 0
    while n < words:
        body.append(para)
        n += 108
    body += ["<h3>Frequently asked questions</h3>",
             "<h4>Does posting daily guarantee growth?</h4>",
             "No. Consistency helps distribution, but nothing guarantees an outcome.",
             "<h3>The bottom line</h3>",
             "Test, measure honestly, and keep what the data supports."]
    return {"title": "Testing Ideas Without Fooling Yourself",
            "category": "Analytics",
            "meta": "x" * 155,
            "excerpt": "A practical guide to testing content ideas honestly.",
            "image_prompt": "A creator's desk with a notebook of test ideas",
            "body": body}


@pytest.mark.asyncio
async def test_generator_refuses_dev_provider(monkeypatch):
    monkeypatch.setattr("app.services.ai.base.get_ai_provider",
                        lambda name="": DevMuseProvider())
    async with SessionLocal() as db:
        before = await _post_count(db)
        out = await generator.generate_article(db)
        assert out["status"] == "skipped"
        assert "dev fallback" in out["reason"]
        assert await _post_count(db) == before


@pytest.mark.asyncio
async def test_generator_publishes_real_article(monkeypatch):
    monkeypatch.setattr("app.services.ai.base.get_ai_provider",
                        lambda name="": _FakeProvider(_good_payload()))

    async def fake_image(slug, prompt):
        return "https://res.cloudinary.com/test/blog.jpg"
    monkeypatch.setattr(generator, "_make_image", fake_image)

    async with SessionLocal() as db:
        out = await generator.generate_article(db)
        assert out["status"] == "published", out
        post = (await db.execute(select(BlogPost).where(
            BlogPost.slug == out["slug"]))).scalar_one()
        assert post.source == "ai"
        assert post.word_count >= 1400
        run = (await db.execute(select(BlogRun).order_by(
            BlogRun.id.desc()).limit(1))).scalar_one()
        assert run.status == "published"


@pytest.mark.asyncio
async def test_generator_skips_short_article(monkeypatch):
    payload = _good_payload()
    payload["body"] = ["<h3>Short</h3>"] + ["too short"] * 12
    monkeypatch.setattr("app.services.ai.base.get_ai_provider",
                        lambda name="": _FakeProvider(payload))
    async with SessionLocal() as db:
        before = await _post_count(db)
        out = await generator.generate_article(db)
        assert out["status"] == "skipped"
        assert "too short" in out["reason"]
        assert await _post_count(db) == before


# ---------------------------------------------------------------------------
# Manual controls: auth + hand publishing
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_manual_create_requires_auth(client):
    payload = {"title": "Hand Written Post", "body": ["<p>Hello</p>"] * 3}
    r = await client.post("/api/v1/blog/posts", json=payload)
    assert r.status_code == 401
    r = await client.post("/api/v1/blog/run")
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_manual_create_with_curator_token(client, monkeypatch):
    monkeypatch.setenv("VIRELLO_CURATOR_TOKEN", "test-token-123")
    payload = {"title": "Hand Written Post",
               "category": "Content",
               "body": ["<p>Written by a human operator.</p>"] * 3}
    r = await client.post("/api/v1/blog/posts", json=payload,
                          headers={"X-Curator-Token": "test-token-123"})
    assert r.status_code == 201
    slug = r.json()["slug"]
    d = await client.get(f"/api/v1/blog/posts/{slug}")
    assert d.status_code == 200
    assert d.json()["title"] == "Hand Written Post"
    s = await client.get("/api/v1/blog/status",
                         headers={"X-Curator-Token": "test-token-123"})
    assert s.status_code == 200
    assert s.json()["published_posts"] >= 1
