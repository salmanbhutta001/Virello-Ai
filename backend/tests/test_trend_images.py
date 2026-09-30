"""Trending topic display images: Wikipedia-first, cached, stylized fallback.

Covers app.services.discovery.trend_images:
- topic_key normalization
- Wikipedia pageimages: hit returns the real photo URL; missing page / HTTP
  error returns "" (never fabricated)
- deterministic generated URL per topic (stable cache key, no regeneration)
- thematic prompt safety: abstract only — never photorealistic, never a
  depiction of a real person (no faces/portraits)
- DB cache roundtrip: resolve once, served from cache afterwards
- resolve_trend_thumbnails fills only missing thumbnail_url, leaves the
  existing API shape untouched
"""
import pytest
import pytest_asyncio
import httpx

import app.main  # noqa: F401 — registers all models so init_db creates every table
from app.core.database import SessionLocal
from app.services.discovery import trend_images as ti


# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

def test_topic_key_normalizes():
    assert ti.topic_key("  Christa   Pike ") == "christa pike"
    assert ti.topic_key("") == ""
    assert ti.topic_key("2026 Asian Games MEDAL table") == "2026 asian games medal table"


def test_generated_url_is_deterministic_per_topic():
    u1 = ti.generated_image_url("christa pike", "Christa Pike")
    u2 = ti.generated_image_url("christa pike", "Christa Pike")
    u3 = ti.generated_image_url("dennis haskins", "Dennis Haskins")
    assert u1 == u2
    assert u1 != u3
    assert u1.startswith("https://image.pollinations.ai/prompt/")


def test_thematic_prompt_is_abstract_and_safe():
    # A real person's name must NEVER become a fake photo prompt.
    p = ti.thematic_prompt("Christa Pike").lower()
    for guard in ("no photorealism", "no real people", "no human figures",
                  "no faces", "no portraits", "no text",
                  "pure abstract geometric composition"):
        assert guard in p, f"missing guard: {guard}"
    # Must not ask for a literal depiction.
    assert "photograph of christa pike" not in p


def test_looks_like_person_name():
    assert ti.looks_like_person_name("Christa Pike")
    assert ti.looks_like_person_name("Case Keenum")
    assert ti.looks_like_person_name("Mary Jane Watson")
    assert not ti.looks_like_person_name("2026 Asian Games medal table")
    assert not ti.looks_like_person_name("India at the 2026 Asian Games")
    assert not ti.looks_like_person_name("iPhone")
    assert not ti.looks_like_person_name("")


def test_thematic_prompt_handles_empty():
    p = ti.thematic_prompt("")
    assert "trending topic" in p.lower()


# ---------------------------------------------------------------------------
# Wikipedia pageimages (mocked HTTP)
# ---------------------------------------------------------------------------

class _FakeResp:
    def __init__(self, status=200, payload=None):
        self.status_code = status
        self._payload = payload or {}

    def json(self):
        return self._payload


class _FakeClient:
    def __init__(self, resp):
        self._resp = resp
        self.seen_urls = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    async def get(self, url, **kw):
        self.seen_urls.append(url)
        return self._resp


def _patch_client(monkeypatch, resp):
    fake = _FakeClient(resp)
    monkeypatch.setattr(
        ti.httpx, "AsyncClient", lambda *a, **k: fake)
    return fake


@pytest.mark.asyncio
async def test_wikipedia_pageimage_hit(monkeypatch):
    payload = {"query": {"pages": {"123": {
        "pageid": 123, "title": "Dennis Haskins",
        "thumbnail": {"source": "https://upload.wikimedia.org/x.jpg", "width": 800},
    }}}}
    fake = _patch_client(monkeypatch, _FakeResp(200, payload))
    url = await ti.fetch_wikipedia_pageimage("Dennis Haskins")
    assert url == "https://upload.wikimedia.org/x.jpg"
    assert "wikipedia.org/w/api.php" in fake.seen_urls[0]
    assert "prop=pageimages" in fake.seen_urls[0]


@pytest.mark.asyncio
async def test_wikipedia_pageimage_missing_page(monkeypatch):
    payload = {"query": {"pages": {"-1": {"title": "Nope", "missing": ""}}}}
    _patch_client(monkeypatch, _FakeResp(200, payload))
    assert await ti.fetch_wikipedia_pageimage("Nope") == ""


@pytest.mark.asyncio
async def test_wikipedia_pageimage_http_error(monkeypatch):
    _patch_client(monkeypatch, _FakeResp(500, {}))
    assert await ti.fetch_wikipedia_pageimage("Anything") == ""


@pytest.mark.asyncio
async def test_wikipedia_pageimage_empty_query_no_http(monkeypatch):
    called = []
    monkeypatch.setattr(ti.httpx, "AsyncClient",
                        lambda *a, **k: (_ for _ in ()).throw(
                            AssertionError("must not call HTTP")))
    assert await ti.fetch_wikipedia_pageimage("   ") == ""


# ---------------------------------------------------------------------------
# Cache + resolver (real DB via SessionLocal, mocked network)
# ---------------------------------------------------------------------------

@pytest_asyncio.fixture
async def db():
    async with SessionLocal() as s:
        yield s


@pytest.mark.asyncio
async def test_cache_roundtrip(db):
    key = "christa pike test"
    assert await ti.get_cached_image(db, key) is None
    await ti.put_cached_image(db, key, "https://example.com/x.jpg", "wikipedia")
    row = await ti.get_cached_image(db, key)
    assert row is not None
    assert row.image_url == "https://example.com/x.jpg"
    assert row.kind == "wikipedia"
    # update path
    await ti.put_cached_image(db, key, "https://example.com/y.jpg", "generated")
    row = await ti.get_cached_image(db, key)
    assert row.image_url == "https://example.com/y.jpg"
    assert row.kind == "generated"


@pytest.mark.asyncio
async def test_resolve_uses_cache_without_network(db, monkeypatch):
    key = ti.topic_key("Cached Topic")
    await ti.put_cached_image(db, key, "https://example.com/cached.jpg", "wikipedia")

    def _boom(*a, **k):
        raise AssertionError("network must not be touched on cache hit")

    monkeypatch.setattr(ti, "wikipedia_topic_info", _boom)
    trends = [{"query": "Cached Topic", "thumbnail_url": ""}]
    await ti.resolve_trend_thumbnails(trends, db)
    assert trends[0]["thumbnail_url"] == "https://example.com/cached.jpg"


@pytest.mark.asyncio
async def test_resolve_prefers_wikipedia_then_caches(db, monkeypatch):
    async def _fake_info(query, lang="en", timeout=8.0):
        return {"image_url": "https://upload.wikimedia.org/real.jpg",
                "is_person": False}

    monkeypatch.setattr(ti, "wikipedia_topic_info", _fake_info)
    trends = [{"query": "Fresh Topic", "thumbnail_url": ""}]
    await ti.resolve_trend_thumbnails(trends, db)
    assert trends[0]["thumbnail_url"] == "https://upload.wikimedia.org/real.jpg"
    row = await ti.get_cached_image(db, ti.topic_key("Fresh Topic"))
    assert row is not None and row.kind == "wikipedia"


@pytest.mark.asyncio
async def test_resolve_skips_generation_for_person_topics(db, monkeypatch):
    """No real photo + person topic => no fabricated likeness, ever."""
    async def _no_photo_person(query, lang="en", timeout=8.0):
        return {"image_url": "", "is_person": True}

    monkeypatch.setattr(ti, "wikipedia_topic_info", _no_photo_person)

    def _boom(coro):
        coro.close()
        raise AssertionError("generation must not be scheduled for people")

    monkeypatch.setattr(ti.asyncio, "create_task", _boom)
    try:
        trends = [{"query": "Some Person With No Photo"}]
        await ti.resolve_trend_thumbnails(trends, db)
    finally:
        import asyncio as _aio
        monkeypatch.setattr(ti.asyncio, "create_task", _aio.create_task)
    assert trends[0].get("thumbnail_url", "") == ""


@pytest.mark.asyncio
async def test_resolve_skips_generation_for_name_like_topics(db, monkeypatch):
    """Name-shaped query with no Wikipedia info => still no likeness."""
    async def _no_info(query, lang="en", timeout=8.0):
        return {"image_url": "", "is_person": False}

    monkeypatch.setattr(ti, "wikipedia_topic_info", _no_info)

    def _boom(coro):
        coro.close()
        raise AssertionError("generation must not be scheduled for names")

    monkeypatch.setattr(ti.asyncio, "create_task", _boom)
    try:
        trends = [{"query": "Christa Pike"}]
        await ti.resolve_trend_thumbnails(trends, db)
    finally:
        import asyncio as _aio
        monkeypatch.setattr(ti.asyncio, "create_task", _aio.create_task)
    assert trends[0].get("thumbnail_url", "") == ""


@pytest.mark.asyncio
async def test_resolve_schedules_generation_when_no_real_image(db, monkeypatch):
    async def _no_info(query, lang="en", timeout=8.0):
        return {"image_url": "", "is_person": False}

    monkeypatch.setattr(ti, "wikipedia_topic_info", _no_info)
    spawned = []
    orig_create = ti.asyncio.create_task

    def _spy(coro):
        spawned.append(coro)
        coro.close()
        class _D:
            pass
        return _D()

    monkeypatch.setattr(ti.asyncio, "create_task", _spy)
    try:
        trends = [{"query": "Obscure News Headline XYZ"}]
        await ti.resolve_trend_thumbnails(trends, db)
    finally:
        monkeypatch.setattr(ti.asyncio, "create_task", orig_create)
    # No thumbnail this load (fallback shows), generation scheduled.
    assert trends[0].get("thumbnail_url", "") == ""
    assert len(spawned) == 1


@pytest.mark.asyncio
async def test_resolve_leaves_existing_thumbnails_alone(db, monkeypatch):
    async def _boom(*a, **k):
        raise AssertionError("must not resolve topics that already have images")

    monkeypatch.setattr(ti, "wikipedia_topic_info", _boom)
    trends = [{"query": "Has Image", "thumbnail_url": "https://example.com/a.jpg"}]
    await ti.resolve_trend_thumbnails(trends, db)
    assert trends[0]["thumbnail_url"] == "https://example.com/a.jpg"


@pytest.mark.asyncio
async def test_resolve_empty_list_noop(db):
    await ti.resolve_trend_thumbnails([], db)  # must not raise
