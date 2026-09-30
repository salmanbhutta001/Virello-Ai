"""Phase 4 — AI Commerce: catalog CRUD, leads, compare, orders, honesty."""
import uuid

import httpx
import pytest
import pytest_asyncio

from app.core.database import SessionLocal
from app.core.security import create_token
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
        u = User(email=f"commerce_{uuid.uuid4().hex[:8]}@test.com",
                 name="Commerce Tester", preferred_language="en")
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = str(u.id)
    yield uid


def _auth(uid: str) -> dict:
    from datetime import timedelta
    token = create_token(str(uid), timedelta(minutes=30))
    return {"Authorization": f"Bearer {token}"}


def _title():
    return f"Test Widget {uuid.uuid4().hex[:8]}"


@pytest.mark.asyncio
async def test_empty_catalog_is_honest(client: httpx.AsyncClient, user):
    # Use a search that matches nothing → honest empty list, no fake items.
    r = await client.get("/api/v1/commerce/products",
                         params={"q": f"zzz-no-such-{uuid.uuid4().hex}"}, headers=_auth(user))
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["products"] == []
    assert j["total"] == 0


@pytest.mark.asyncio
async def test_create_and_browse_product(client: httpx.AsyncClient, user):
    title = _title()
    r = await client.post("/api/v1/commerce/products", json={
        "title": title,
        "description": "A genuinely listed test product",
        "price_cents": 1999,
        "currency": "USD",
        "category": "all",
        "image_urls": ["https://example.com/img1.jpg"],
        "stock_qty": 5,
    }, headers=_auth(user))
    assert r.status_code == 201, r.text
    p = r.json()
    assert p["title"] == title
    assert p["price_cents"] == 1999
    assert p["price_display"] == "$19.99"
    assert p["is_active"] is True
    pid = p["id"]

    # Browse finds it via search.
    r = await client.get("/api/v1/commerce/products", params={"q": title}, headers=_auth(user))
    assert r.status_code == 200
    ids = [x["id"] for x in r.json()["products"]]
    assert pid in ids

    # Detail + related.
    r = await client.get(f"/api/v1/commerce/products/{pid}", headers=_auth(user))
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["product"]["id"] == pid
    assert j["share_slug"]
    assert j["is_owner"] is True

    # Public share page (no auth needed) counts a real view.
    r = await client.get(f"/api/v1/commerce/products/slug/{j['share_slug']}")
    assert r.status_code == 200
    assert r.json()["product"]["id"] == pid
    assert r.json()["page_views"] >= 1

    # Cleanup: deactivate.
    r = await client.delete(f"/api/v1/commerce/products/{pid}", headers=_auth(user))
    assert r.status_code == 200
    r = await client.get(f"/api/v1/commerce/products/{pid}", headers=_auth(user))
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_create_rejects_bad_category_and_images(client: httpx.AsyncClient, user):
    r = await client.post("/api/v1/commerce/products", json={
        "title": _title(), "price_cents": 100, "category": "nope"}, headers=_auth(user))
    assert r.status_code == 400
    r = await client.post("/api/v1/commerce/products", json={
        "title": _title(), "price_cents": 100,
        "image_urls": ["ftp://evil.example/x.jpg"]}, headers=_auth(user))
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_lead_dedupe(client: httpx.AsyncClient, user):
    title = _title()
    r = await client.post("/api/v1/commerce/products", json={
        "title": title, "price_cents": 500, "stock_qty": 2}, headers=_auth(user))
    pid = r.json()["id"]
    try:
        r = await client.post(f"/api/v1/commerce/products/{pid}/lead",
                              json={"source": "shop"}, headers=_auth(user))
        assert r.status_code == 200
        assert r.json()["ok"] is True
        # Second tap within 24h dedupes — no inflated counts.
        r = await client.post(f"/api/v1/commerce/products/{pid}/lead",
                              json={"source": "shop"}, headers=_auth(user))
        assert r.json().get("deduped") is True

        r = await client.get("/api/v1/commerce/my/leads", headers=_auth(user))
        assert r.status_code == 200
        mine = [l for l in r.json()["leads"] if l["product_id"] == pid]
        assert len(mine) == 1
    finally:
        await client.delete(f"/api/v1/commerce/products/{pid}", headers=_auth(user))


@pytest.mark.asyncio
async def test_compare_never_invents_ratings(client: httpx.AsyncClient, user):
    ids = []
    try:
        for i in range(2):
            r = await client.post("/api/v1/commerce/products", json={
                "title": f"{_title()} {i}", "price_cents": 100 * (i + 1),
                "stock_qty": i + 1}, headers=_auth(user))
            ids.append(r.json()["id"])
        r = await client.post("/api/v1/commerce/products/compare",
                              json={"product_ids": ids}, headers=_auth(user))
        assert r.status_code == 200, r.text
        j = r.json()
        assert len(j["products"]) == 2
        assert j["missing"] == []
        assert "not available yet" in j["note"]
        # No product carries a rating field — the note above is the only
        # place the word appears, and it honestly says ratings don't exist.
        for p in j["products"]:
            assert not any("rating" in k.lower() or "review" in k.lower()
                           for k in p.keys())
    finally:
        for pid in ids:
            await client.delete(f"/api/v1/commerce/products/{pid}", headers=_auth(user))


@pytest.mark.asyncio
async def test_order_is_honest_about_checkout(client: httpx.AsyncClient, user):
    # Another user must own the product (can't buy own) — use a second
    # product then verify self-purchase is rejected.
    r = await client.post("/api/v1/commerce/products", json={
        "title": _title(), "price_cents": 2500, "stock_qty": 3}, headers=_auth(user))
    pid = r.json()["id"]
    try:
        r = await client.post("/api/v1/commerce/orders",
                              json={"product_id": pid, "provider": "paypal"}, headers=_auth(user))
        assert r.status_code == 400  # own product
        assert "own product" in r.json()["detail"]
    finally:
        await client.delete(f"/api/v1/commerce/products/{pid}", headers=_auth(user))


@pytest.mark.asyncio
async def test_my_products_lists_mine(client: httpx.AsyncClient, user):
    title = _title()
    r = await client.post("/api/v1/commerce/products", json={
        "title": title, "price_cents": 999, "stock_qty": 1}, headers=_auth(user))
    pid = r.json()["id"]
    try:
        r = await client.get("/api/v1/commerce/my/products", headers=_auth(user))
        assert r.status_code == 200
        assert any(p["id"] == pid for p in r.json())
    finally:
        await client.delete(f"/api/v1/commerce/products/{pid}", headers=_auth(user))

@pytest.mark.asyncio
async def test_affiliate_product_fields_and_sync(client: httpx.AsyncClient, user):
    # Affiliate product requires a valid affiliate_url.
    r = await client.post("/api/v1/commerce/products", json={
        "title": "Affiliate No URL", "price_cents": 100,
        "is_affiliate": True,
    }, headers=_auth(user))
    assert r.status_code == 400
    # Valid affiliate product.
    r = await client.post("/api/v1/commerce/products", json={
        "title": "Amazon Affiliate Widget", "price_cents": 2599,
        "is_affiliate": True,
        "affiliate_url": "https://www.amazon.com/dp/B0EXAMPLE?tag=virello-20",
        "affiliate_provider": "amazon",
    }, headers=_auth(user))
    assert r.status_code == 201
    p = r.json()
    assert p["is_affiliate"] is True
    assert p["affiliate_provider"] == "amazon"
    assert p["affiliate_url"].startswith("https://")
    pid = p["id"]
    # Sync without PA-API credentials → honest not_configured, nothing changed.
    r = await client.post(f"/api/v1/commerce/products/{pid}/sync", headers=_auth(user))
    assert r.status_code == 200
    j = r.json()
    assert j["status"] == "not_configured"
    assert "PA-API" in j["message"] or "credentials" in j["message"]
    assert j["price_changed"] is False
    # Sync on a NON-affiliate product is rejected.
    r = await client.post("/api/v1/commerce/products", json={
        "title": "Regular Thing", "price_cents": 500}, headers=_auth(user))
    assert r.status_code == 201
    pid2 = r.json()["id"]
    r = await client.post(f"/api/v1/commerce/products/{pid2}/sync", headers=_auth(user))
    assert r.status_code == 400
    await client.delete(f"/api/v1/commerce/products/{pid}", headers=_auth(user))
    await client.delete(f"/api/v1/commerce/products/{pid2}", headers=_auth(user))
