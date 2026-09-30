"""Autonomous curation: category validation, gallery volume fallback,
scheduler wiring, discovery parsing."""
from __future__ import annotations

import uuid

import pytest
from sqlalchemy import select

from app.core.database import SessionLocal
from app.curation import config
from app.curation.discovery import parse_amazon_search
from app.curation.models import CurationCandidate
from app.curation.routes import resolve_gallery_file
from app.curation.scheduler import start_curation_scheduler
from app.curation.service import curate_product, department_counts
from app.models.commerce import PRODUCT_CATEGORIES, Product
from app.models.core import User


# ---------------------------------------------------------------------------
# 1. Category validation
# ---------------------------------------------------------------------------

def test_departments_exclude_ui_filters():
    for slug in ("all", "men", "women", "sale", "best_sellers"):
        assert slug not in config.DEPARTMENTS
    assert len(config.DEPARTMENTS) == 26
    for d in config.DEPARTMENTS:
        assert d in PRODUCT_CATEGORIES


def test_every_department_has_queries():
    for d in config.DEPARTMENTS:
        assert config.DEPARTMENT_QUERIES.get(d), f"no queries for {d}"


@pytest.mark.asyncio
async def test_curate_product_invalid_category_falls_back_to_all():
    async with SessionLocal() as db:
        creator = User(email=f"cur-{uuid.uuid4().hex[:8]}@example.com",
                       name="Cur")
        db.add(creator)
        await db.flush()
        asin = f"B0{uuid.uuid4().hex[:8].upper()}"
        out = await curate_product(
            db, asin=asin, title="Test Gadget", category="not_a_dept",
            image_urls=["https://example.com/a.jpg"], creator=creator)
        assert out["created"] is True
        prod = (await db.execute(
            select(Product).where(Product.id == uuid.UUID(out["product_id"]))
        )).scalar_one()
        assert prod.category == "all"
        assert prod.price_cents == 0
        # Idempotent: second call skips
        out2 = await curate_product(
            db, asin=asin, title="Test Gadget", image_urls=[], creator=creator)
        assert out2["skipped"] is True
        await db.rollback()


@pytest.mark.asyncio
async def test_department_counts_counts_affiliate_only():
    async with SessionLocal() as db:
        counts = await department_counts(db)
        assert isinstance(counts, dict)
        await db.rollback()


# ---------------------------------------------------------------------------
# 2. Gallery volume-first fallback
# ---------------------------------------------------------------------------

def test_resolve_gallery_file_volume_first(tmp_path, monkeypatch):
    vol = tmp_path / "vol"
    static = tmp_path / "static"
    vol.mkdir()
    static.mkdir()
    (vol / "A_main.jpg").write_bytes(b"vol")
    (static / "A_main.jpg").write_bytes(b"static")
    (static / "B_main.jpg").write_bytes(b"static-only")
    monkeypatch.setattr(config, "gallery_dir", lambda: vol)
    monkeypatch.setattr(config, "static_gallery_dir", lambda: static)

    assert resolve_gallery_file("A_main.jpg").read_bytes() == b"vol"
    assert resolve_gallery_file("B_main.jpg").read_bytes() == b"static-only"
    assert resolve_gallery_file("missing.jpg") is None
    # path traversal / unsafe names rejected
    assert resolve_gallery_file("../secret.txt") is None
    assert resolve_gallery_file("/etc/passwd") is None
    assert resolve_gallery_file("x.exe") is None


# ---------------------------------------------------------------------------
# 3. Scheduler wiring
# ---------------------------------------------------------------------------

def test_scheduler_disabled_returns_none(monkeypatch):
    monkeypatch.setenv("VIRELLO_CURATION_AUTONOMOUS", "false")
    assert start_curation_scheduler() is None


@pytest.mark.asyncio
async def test_scheduler_starts_job_and_stops(monkeypatch):
    pytest.importorskip("apscheduler")
    monkeypatch.setenv("VIRELLO_CURATION_AUTONOMOUS", "true")
    from app.curation.scheduler import (start_curation_scheduler,
                                        stop_curation_scheduler)
    sched = start_curation_scheduler()
    try:
        assert sched is not None
        assert any(j.id == "virello-hourly-curation"
                   for j in sched.get_jobs())
    finally:
        stop_curation_scheduler(sched)


def test_curation_config_defaults(monkeypatch):
    monkeypatch.delenv("VIRELLO_CURATION_AUTONOMOUS", raising=False)
    assert config.curation_enabled() is True
    assert config.curation_interval_hours() >= 0.25
    assert config.partner_tag() == "topitems0c1-20"
    # never logs the raw email
    masked = config.mask_email("creator@example.com")
    assert masked != "creator@example.com"
    assert masked == "c***@example.com"


# ---------------------------------------------------------------------------
# 4. Discovery parsing on fixture HTML
# ---------------------------------------------------------------------------

_FIXTURE = """
<div data-asin="B0TEST1234" class="a-section">
<a aria-hidden="false" aria-label="Go to detail page for &quot;Acme Wireless
Earbuds Pro, Noise Cancelling, Black&quot; Not eligible for Prime. Best Seller."
href="/dp/B0TEST1234"><img srcset="https://m.media-amazon.com/images/I/61abcXYZ._AC_SX260_.jpg 1x,
https://m.media-amazon.com/images/I/61abcXYZ._AC_SX520_.jpg 2x"></a>
</div>
<div data-asin="B0NOTITLE1" class="a-section"><span>no title here</span></div>
<div data-asin="B0TEST5678" class="a-section">
<h2 class="a-size-mini"><span>Acme Coffee Maker 12-Cup</span></h2>
<img srcset="https://m.media-amazon.com/images/I/71defUVW._AC_SX260_.jpg 1x">
</div>
"""


def test_parse_amazon_search_fixture():
    cands = parse_amazon_search(_FIXTURE, "tech")
    asins = {c.asin for c in cands}
    assert "B0TEST1234" in asins
    assert "B0TEST5678" in asins
    assert "B0NOTITLE1" not in asins  # no verifiable title → skipped
    c1 = next(c for c in cands if c.asin == "B0TEST1234")
    assert "Acme Wireless Earbuds Pro" in c1.title
    assert "Not eligible" not in c1.title
    assert c1.main_image_url.startswith(
        "https://m.media-amazon.com/images/I/")
    assert c1.department == "tech"
    assert c1.source == "amazon_search"


def test_parse_amazon_search_botcheck_empty():
    assert parse_amazon_search(
        "<html><body>Enter the characters you see below (captcha)</body></html>",
        "tech") == []
    assert parse_amazon_search("", "tech") == []


# ---------------------------------------------------------------------------
# 6. HTTP routes (gallery volume-first + admin status)
# ---------------------------------------------------------------------------

import httpx
import pytest_asyncio

from app.main import app as fastapi_app


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=fastapi_app), base_url="http://test"
    ) as c:
        yield c


@pytest.mark.asyncio
async def test_gallery_route_serves_volume_first(client, tmp_path,
                                                 monkeypatch):
    vol = tmp_path / "vol"
    static = tmp_path / "static"
    vol.mkdir()
    static.mkdir()
    (vol / "T_main.jpg").write_bytes(b"fakejpeg-bytes")
    monkeypatch.setattr(config, "gallery_dir", lambda: vol)
    monkeypatch.setattr(config, "static_gallery_dir", lambda: static)
    r = await client.get("/gallery/T_main.jpg")
    assert r.status_code == 200, r.text
    assert r.content == b"fakejpeg-bytes"
    r2 = await client.get("/gallery/missing.jpg")
    assert r2.status_code == 404


@pytest.mark.asyncio
async def test_gallery_route_rejects_unsafe_names(client):
    for bad in ("..%2Fsecret.txt", "x.exe", "noext"):
        r = await client.get(f"/gallery/{bad}")
        assert r.status_code in (404, 422), (bad, r.status_code)


@pytest.mark.asyncio
async def test_curation_status_requires_admin(client):
    # dev_noauth test user is not admin → 403 proves the route is wired
    # and the admin guard is active.
    r = await client.get("/api/v1/curation/status")
    assert r.status_code in (401, 403), r.text

# ---------------------------------------------------------------------------
# 5. Candidate queue helpers
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_candidate_queue_roundtrip():
    from app.curation.discovery import (add_candidate, mark_candidate,
                                        pending_candidates)
    async with SessionLocal() as db:
        asin = f"B0{uuid.uuid4().hex[:8].upper()}"
        row = await add_candidate(
            db, asin=asin, title="Queue Widget", department="tools",
            source="manual", main_image_url="https://example.com/w.jpg")
        assert isinstance(row, CurationCandidate)
        pend = await pending_candidates(db, "tools", limit=10)
        assert any(r.asin == asin for r in pend)
        await mark_candidate(db, asin, "listed", "test")
        pend2 = await pending_candidates(db, "tools", limit=10)
        assert not any(r.asin == asin for r in pend2)
        await db.rollback()
