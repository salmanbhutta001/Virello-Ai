"""AI Commerce API (Phase 4): product catalog, shareable product pages,
leads, comparison, orders.

Honesty contract:
- No fake products, prices, ratings, or sales. Empty catalog → empty list.
- There is no review/rating system yet, so the API never returns ratings.
- ``best_sellers`` sorts by real product-page views until order volume
  exists (documented in the response as ``sort_note``).

Money movement:
- This router NEVER touches provider payment APIs. Checkout goes through
  the existing billing pipeline:
    1. Buyer: POST /api/v1/commerce/orders {product_id, provider}
       → CommerceOrder(status="created").
    2. Buyer: POST /api/v1/billing/orders {provider, kind:"commerce",
       idempotency_key, metadata:{commerce_order_id}} → provider approval.
       (Billing's OrderIn.kind currently accepts subscription|credits; the
       commerce kind is carried in metadata and resolved by the verify
       hook below — billing code change is NOT required for listing and
       lead flows, only for live checkout.)
    3. After payer approval: POST /api/v1/billing/verify →
       on verified completion the commerce hook links the Transaction and
       flips the CommerceOrder to "paid".
  Until the billing "commerce" kind ships, /commerce/orders returns the
  order with ``checkout_ready: false`` and an honest message — the Shop
  UI surfaces "Checkout via provider — coming soon" instead of a fake
  buy button that takes money nowhere.
"""
from __future__ import annotations

import re
import secrets
import uuid

from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import case, desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.commerce import (
    PRODUCT_CATEGORIES,
    CommerceLead,
    CommerceOrder,
    Product,
    ProductPage,
    WishlistItem,
)
from app.models.core import User

router = APIRouter(prefix="/commerce", tags=["commerce"])

_optional_bearer = HTTPBearer(auto_error=False)


async def _optional_user(
    db: AsyncSession = Depends(get_db),
    creds: HTTPAuthorizationCredentials | None = Depends(_optional_bearer),
) -> User | None:
    """Best-effort auth: returns the user or None (for public lead capture)."""
    from app.core.config import settings

    if creds is None:
        if settings.dev_noauth:
            # DEV ONLY — mirror get_current_user's dev bypass.
            res = await db.execute(
                select(User).where(User.email == "dev@virello.app"))
            user = res.scalar_one_or_none()
            if user is None:
                user = User(email="dev@virello.app", name="Dev", locale="en")
                db.add(user)
                await db.commit()
                await db.refresh(user)
            return user
        return None
    try:
        from app.core.security import decode_token

        user_id = decode_token(creds.credentials)
        res = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
        return res.scalar_one_or_none()
    except Exception:
        return None


# ---------------------------------------------------------------- schemas

class ProductIn(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str = Field(default="", max_length=5000)
    price_cents: int = Field(..., ge=0, le=100_000_000)
    currency: str = Field(default="USD", max_length=8)
    category: str = Field(default="all", max_length=64)
    image_urls: list[str] = Field(default_factory=list, max_length=10)
    stock_qty: int = Field(default=0, ge=0)
    # Affiliate (e.g. Amazon Associates): outbound merchant link. Virello
    # never takes payment for affiliate products; the UI must show the
    # "Affiliate link — we may earn a commission" disclosure.
    is_affiliate: bool = False
    affiliate_url: str = Field(default="", max_length=2000)
    affiliate_provider: str = Field(default="", max_length=32)


class ProductPatch(BaseModel):
    title: str | None = Field(default=None, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    price_cents: int | None = Field(default=None, ge=0, le=100_000_000)
    currency: str | None = Field(default=None, max_length=8)
    category: str | None = Field(default=None, max_length=64)
    image_urls: list[str] | None = Field(default=None, max_length=10)
    stock_qty: int | None = Field(default=None, ge=0)
    is_active: bool | None = None
    is_affiliate: bool | None = None
    affiliate_url: str | None = Field(default=None, max_length=2000)
    affiliate_provider: str | None = Field(default=None, max_length=32)


class ProductOut(BaseModel):
    id: str
    creator_id: str
    title: str
    description: str
    price_cents: int
    price_display: str
    currency: str
    category: str
    image_urls: list[str]
    stock_qty: int
    is_active: bool
    views: int
    is_affiliate: bool
    affiliate_url: str | None = None
    affiliate_provider: str | None = None
    # Amazon ASIN (10-char product id). The Product table has NO asin
    # column — the ASIN lives only inside affiliate_url as /dp/<ASIN>.
    # Extracted in _to_out so list items and detail responses carry it
    # (frontend product pages look products up by ASIN).
    asin: str | None = None
    trend_score: int = 0
    trend_signals: str = ""
    created_at: str


class CompareIn(BaseModel):
    product_ids: list[str] = Field(..., min_length=2, max_length=4)


class LeadIn(BaseModel):
    source: str = Field(default="shop", max_length=32)


class OrderIn(BaseModel):
    product_id: str
    provider: str = Field(default="", max_length=32)  # paypal|payoneer|google_pay


# ---------------------------------------------------------------- helpers

def _slugify(title: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60]
    return f"{slug or 'product'}-{secrets.token_hex(3)}"


def _price_display(price_cents: int, currency: str) -> str:
    symbols = {"USD": "$", "EUR": "€", "GBP": "£", "PKR": "Rs ", "INR": "₹", "AED": "د.إ "}
    sym = symbols.get(currency.upper(), f"{currency.upper()} ")
    return f"{sym}{price_cents / 100:,.2f}"


_ASIN_RE = re.compile(r"^[A-Z0-9]{10}$")
# ASIN inside an affiliate URL: /dp/<10-char ASIN> followed by a
# non-alphanumeric char (or end of string) so a longer token can't
# false-match a 10-char prefix.
_ASIN_IN_URL = re.compile(r"/dp/([A-Z0-9]{10})(?![A-Z0-9])")


def _asin_of_url(url: str | None) -> str | None:
    """Extract the ASIN from an affiliate URL (…/dp/<ASIN>?tag=…).

    The Product table has no asin column — this is the only source of
    the ASIN for catalog rows. Mirrors app.routers.shop._asin_of_url."""
    m = _ASIN_IN_URL.search(url or "")
    return m.group(1) if m else None


def _to_out(p: Product) -> ProductOut:
    return ProductOut(
        id=str(p.id),
        creator_id=str(p.creator_id),
        title=p.title,
        description=p.description or "",
        price_cents=p.price_cents,
        price_display=_price_display(p.price_cents, p.currency),
        currency=p.currency,
        category=p.category,
        image_urls=list(p.image_urls or []),
        stock_qty=p.stock_qty,
        is_active=p.is_active,
        views=p.views or 0,
        is_affiliate=bool(p.is_affiliate),
        affiliate_url=p.affiliate_url,
        affiliate_provider=p.affiliate_provider,
        asin=_asin_of_url(p.affiliate_url),
        trend_score=int(p.trend_score or 0),
        trend_signals=p.trend_signals or "",
        created_at=p.created_at.isoformat() if p.created_at else "",
    )


def _validate_affiliate_fields(is_affiliate: bool, affiliate_url: str,
                               affiliate_provider: str) -> tuple[str, str]:
    """Normalize + validate affiliate fields. Raises 400 on bad input."""
    from app.services.affiliate.base import supported_affiliate_providers

    url = (affiliate_url or "").strip()
    provider = (affiliate_provider or "").strip().lower()
    if is_affiliate:
        if not url:
            raise HTTPException(400, "affiliate_url is required for affiliate products")
        if not (url.startswith("http://") or url.startswith("https://")):
            raise HTTPException(400, "affiliate_url must be an http(s) URL")
        if provider and provider not in supported_affiliate_providers():
            raise HTTPException(
                400, f"affiliate_provider must be one of {supported_affiliate_providers()}")
        if not provider:
            provider = "amazon"  # default until more providers land
    else:
        url, provider = "", ""
    return url, provider


def _parse_uuid(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except (ValueError, AttributeError):
        raise HTTPException(400, "Invalid id")


async def _get_product(db: AsyncSession, product_id: uuid.UUID) -> Product:
    res = await db.execute(select(Product).where(Product.id == product_id))
    product = res.scalar_one_or_none()
    if product is None:
        raise HTTPException(404, "Product not found")
    return product


# ---------------------------------------------------------------- endpoints

@router.post("/products", response_model=ProductOut, status_code=201)
async def create_product(
    body: ProductIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Creator lists a product. Creates the shareable ProductPage too."""
    category = (body.category or "all").lower()
    if category not in PRODUCT_CATEGORIES:
        raise HTTPException(400, f"category must be one of {PRODUCT_CATEGORIES}")
    image_urls = [u.strip() for u in body.image_urls if u.strip()][:10]
    for u in image_urls:
        if not (u.startswith("http://") or u.startswith("https://")):
            raise HTTPException(400, "image_urls must be http(s) URLs")
    affiliate_url, affiliate_provider = _validate_affiliate_fields(
        body.is_affiliate, body.affiliate_url, body.affiliate_provider)
    product = Product(
        creator_id=user.id,
        title=body.title.strip(),
        description=body.description.strip(),
        price_cents=body.price_cents,
        currency=body.currency.upper(),
        category=category,
        image_urls=image_urls,
        stock_qty=body.stock_qty,
        is_active=True,
        is_affiliate=body.is_affiliate,
        affiliate_url=affiliate_url or None,
        affiliate_provider=affiliate_provider or None,
    )
    db.add(product)
    await db.flush()
    # Shareable page: /p/{slug}
    slug = _slugify(product.title)
    for _ in range(3):  # tiny collision retry
        exists = (
            await db.execute(select(ProductPage.id).where(ProductPage.slug == slug))
        ).scalar_one_or_none()
        if exists is None:
            break
        slug = _slugify(product.title)
    db.add(ProductPage(product_id=product.id, slug=slug))
    await db.commit()
    await db.refresh(product)
    return _to_out(product)


@router.get("/products", response_model=dict)
async def list_products(
    category: str | None = Query(default=None),
    q: str | None = Query(default=None, max_length=120),
    sort: str = Query(default="newest", pattern="^(newest|price_asc|price_desc|popular|trending)$"),
    limit: int = Query(default=24, ge=1, le=60),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    """Browse the catalog. Empty catalog → {"products": [], "total": 0}."""
    stmt = select(Product).where(Product.is_active.is_(True))
    sort_note = ""
    if category and category != "all":
        cat = category.lower()
        if cat == "best_sellers":
            # No order volume yet: rank by real page views, labeled honestly.
            sort = "popular"
            sort_note = "Ranked by product page views (sales tracking coming soon)"
        elif cat in PRODUCT_CATEGORIES:
            stmt = stmt.where(Product.category == cat)
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(Product.title.ilike(like), Product.description.ilike(like))
        )
    if sort == "price_asc":
        stmt = stmt.order_by(Product.price_cents.asc())
    elif sort == "price_desc":
        stmt = stmt.order_by(Product.price_cents.desc())
    elif sort == "popular":
        stmt = stmt.order_by(desc(Product.views))
    elif sort == "trending":
        # Genuinely-trending rail: curator-assigned trend_score from real
        # research (bestseller ranks, review velocity, trend data), refreshed
        # hourly. Time-decayed (~3-day half-life) so the rail keeps updating.
        # The rail is NEVER empty and old products are NEVER removed: scored
        # products rank first by decayed score (a newly-scored product jumps
        # to the top immediately), everything else fills the rail below by
        # real page views, exactly like before.
        dialect = (db.bind.dialect.name if db.bind is not None else "")
        if dialect == "sqlite":
            age_sec = (func.julianday("now") -
                       func.julianday(Product.trending_as_of)) * 86400.0
        else:
            age_sec = func.extract(
                "epoch", func.now() - Product.trending_as_of)
        decayed = case(
            (Product.trending_as_of.is_(None), 0.0),
            else_=func.coalesce(Product.trend_score, 0) /
            (1.0 + age_sec / 259200.0),
        )
        stmt = stmt.order_by(desc(decayed), desc(Product.views))
        sort_note = "Ranked by real trend research, refreshed hourly"
    else:
        stmt = stmt.order_by(desc(Product.created_at))
    total = (await db.execute(
        select(func.count()).select_from(stmt.subquery()))).scalar() or 0
    rows = (await db.execute(stmt.offset(offset).limit(limit))).scalars().all()
    return {
        "products": [_to_out(p).model_dump() for p in rows],
        "total": total,
        "limit": limit,
        "offset": offset,
        "sort_note": sort_note,
    }


@router.get("/products/by-asin/{asin}", response_model=dict)
async def product_by_asin(
    asin: str,
    db: AsyncSession = Depends(get_db),
):
    """Public lookup of one catalog product by Amazon ASIN.

    Fixes /product.html?asin=<older ASIN> showing "Product not found":
    the catalog has no asin column, so the ASIN is matched against the
    /dp/<ASIN> pattern inside affiliate_url (canonical server-built URL
    first, then any /dp/<ASIN> URL — older rows may carry a different
    partner tag). The returned object is a flat list-item shape (same
    fields as GET /products items, including a populated ``asin``), so
    the frontend's renderProductDetailContent can consume it directly.

    Normalization: input is stripped + uppercased. Malformed input
    (not 10 alphanumeric chars) returns 404 — same convention as
    GET /shop/go/{asin} ("unknown product" for a bad ASIN). A
    well-formed but absent ASIN also returns 404 with a clear body.
    """
    asin = (asin or "").strip().upper()
    if not _ASIN_RE.match(asin):
        raise HTTPException(404, "Product not found")
    from app.services.affiliate.amazon import AmazonAffiliateProvider

    canonical_url = AmazonAffiliateProvider().build_affiliate_url(asin)
    rows = (
        await db.execute(
            select(Product).where(
                Product.is_active.is_(True),
                or_(
                    Product.affiliate_url == canonical_url,
                    Product.affiliate_url.ilike(f"%/dp/{asin}%"),
                ),
            )
        )
    ).scalars().all()
    # ilike is only a pre-filter: verify the extracted ASIN in Python so
    # a longer token sharing the 10-char prefix can never false-match.
    product = next((p for p in rows if _asin_of_url(p.affiliate_url) == asin), None)
    if product is None:
        raise HTTPException(404, "Product not found")
    return _to_out(product).model_dump()


@router.get("/products/slug/{slug}", response_model=dict)
async def product_page_by_slug(
    slug: str,
    db: AsyncSession = Depends(get_db),
):
    """Public shareable product page (for /p/{slug} links). Counts a view —
    a genuine event, never fabricated."""
    res = await db.execute(
        select(ProductPage, Product)
        .join(Product, Product.id == ProductPage.product_id)
        .where(ProductPage.slug == slug, Product.is_active.is_(True))
    )
    row = res.one_or_none()
    if row is None:
        raise HTTPException(404, "Product page not found")
    page, product = row
    page.views = (page.views or 0) + 1
    product.views = (product.views or 0) + 1
    await db.commit()
    return {"product": _to_out(product).model_dump(), "page_views": page.views}


@router.get("/products/{product_id}", response_model=dict)
async def product_detail(
    product_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    product = await _get_product(db, _parse_uuid(product_id))
    if not product.is_active:
        raise HTTPException(404, "Product not found")
    related = (
        await db.execute(
            select(Product)
            .where(Product.is_active.is_(True), Product.id != product.id,
                   Product.category == product.category)
            .order_by(desc(Product.views)).limit(6)
        )
    ).scalars().all()
    if not related:
        related = (
            await db.execute(
                select(Product)
                .where(Product.is_active.is_(True), Product.id != product.id)
                .order_by(desc(Product.views)).limit(6)
            )
        ).scalars().all()
    page = (
        await db.execute(
            select(ProductPage).where(ProductPage.product_id == product.id))
    ).scalar_one_or_none()
    return {
        "product": _to_out(product).model_dump(),
        "related": [_to_out(p).model_dump() for p in related],
        "share_slug": page.slug if page else None,
        "is_owner": str(product.creator_id) == str(user.id),
    }


@router.patch("/products/{product_id}", response_model=ProductOut)
async def update_product(
    product_id: str,
    body: ProductPatch,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    product = await _get_product(db, _parse_uuid(product_id))
    if str(product.creator_id) != str(user.id):
        raise HTTPException(403, "Only the creator can update this product")
    data = body.model_dump(exclude_unset=True)
    if "category" in data and data["category"] not in PRODUCT_CATEGORIES:
        raise HTTPException(400, f"category must be one of {PRODUCT_CATEGORIES}")
    if "image_urls" in data and data["image_urls"] is not None:
        urls = [u.strip() for u in data["image_urls"] if u.strip()][:10]
        for u in urls:
            if not (u.startswith("http://") or u.startswith("https://")):
                raise HTTPException(400, "image_urls must be http(s) URLs")
        data["image_urls"] = urls
    # Affiliate fields: validate as a group against the final is_affiliate.
    aff_keys = {"is_affiliate", "affiliate_url", "affiliate_provider"}
    if aff_keys & set(data.keys()):
        is_aff = data.get("is_affiliate", product.is_affiliate)
        url, provider = _validate_affiliate_fields(
            bool(is_aff),
            data.get("affiliate_url", product.affiliate_url or ""),
            data.get("affiliate_provider", product.affiliate_provider or ""),
        )
        data["is_affiliate"] = bool(is_aff)
        data["affiliate_url"] = url or None
        data["affiliate_provider"] = provider or None
    for key, value in data.items():
        if key == "title" and isinstance(value, str):
            value = value.strip()
        setattr(product, key, value)
    await db.commit()
    await db.refresh(product)
    return _to_out(product)


@router.delete("/products/{product_id}")
async def deactivate_product(
    product_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Soft-delete: deactivates the listing (orders/leads history preserved)."""
    product = await _get_product(db, _parse_uuid(product_id))
    # Hafiz 2026-10-13: admins can deactivate any product.
    if str(product.creator_id) != str(user.id) and not user.is_admin:
        raise HTTPException(403, "Only the creator can remove this product")
    product.is_active = False
    await db.commit()
    return {"ok": True, "deactivated": True}


@router.post("/products/{product_id}/sync", response_model=dict)
async def sync_affiliate_product(
    product_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Re-sync an affiliate product's price/stock from the provider API.

    Honest placeholder: real sync needs the provider's official API
    credentials (e.g. Amazon PA-API 5.0 via Secure Vault). Without them the
    provider reports ``status="not_configured"`` and NOTHING is changed —
    no synthetic prices, ever.
    """
    from app.services.affiliate.base import get_affiliate_provider

    product = await _get_product(db, _parse_uuid(product_id))
    if str(product.creator_id) != str(user.id):
        raise HTTPException(403, "Only the creator can sync this product")
    if not product.is_affiliate:
        raise HTTPException(400, "Only affiliate products can be synced")
    provider = get_affiliate_provider(product.affiliate_provider or "amazon")
    # External id is the last path segment of the affiliate URL when it
    # looks like an ASIN; otherwise we can't sync without PA-API search.
    external_id = (product.affiliate_url or "").rstrip("/").split("/")[-1].split("?")[0]
    result = await provider.sync_product(str(product.id), external_id)
    return {
        "status": result.status,
        "product_id": str(product.id),
        "message": result.message,
        "price_changed": False,
        "stock_changed": False,
    }


@router.post("/products/compare", response_model=dict)
async def compare_products(
    body: CompareIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Side-by-side comparison of 2–4 products. Real stored data only."""
    ids = [_parse_uuid(pid) for pid in dict.fromkeys(body.product_ids)]
    rows = (await db.execute(
        select(Product).where(Product.id.in_(ids), Product.is_active.is_(True))
    )).scalars().all()
    found = {str(p.id): p for p in rows}
    missing = [pid for pid in body.product_ids if pid not in found]
    products = [_to_out(found[pid]).model_dump()
                for pid in body.product_ids if pid in found]
    # Honest comparison table: only fields that exist.
    table = [
        {"field": "Price", "values": [p["price_display"] for p in products]},
        {"field": "Category", "values": [p["category"] for p in products]},
        {"field": "In stock", "values": [str(p["stock_qty"]) for p in products]},
        {"field": "Views", "values": [str(p["views"]) for p in products]},
    ]
    return {"products": products, "comparison": table, "missing": missing,
            "note": "Ratings & reviews are not available yet"}


@router.post("/products/{product_id}/lead")
async def record_lead(
    product_id: str,
    body: LeadIn,
    db: AsyncSession = Depends(get_db),
    user: User | None = Depends(_optional_user),
):
    """Record genuine interest in a product. One lead per user per product
    per day (dedupe) — repeated taps don't inflate counts."""
    product = await _get_product(db, _parse_uuid(product_id))
    if not product.is_active:
        raise HTTPException(404, "Product not found")
    source = (body.source or "shop")[:32]
    if user is not None:
        # Dedupe: same user + product within the last 24h.
        from datetime import datetime, timedelta, timezone

        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        dup = (
            await db.execute(
                select(CommerceLead.id).where(
                    CommerceLead.product_id == product.id,
                    CommerceLead.user_id == user.id,
                    CommerceLead.created_at >= cutoff,
                ).limit(1)
            )
        ).scalar_one_or_none()
        if dup is not None:
            return {"ok": True, "deduped": True}
    lead = CommerceLead(
        product_id=product.id,
        user_id=user.id if user else None,
        source=source,
        status="new",
    )
    db.add(lead)
    await db.commit()
    return {"ok": True, "lead_id": str(lead.id)}


@router.get("/my/products", response_model=list[ProductOut])
async def my_products(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(Product).where(Product.creator_id == user.id)
            .order_by(desc(Product.created_at))
        )
    ).scalars().all()
    return [_to_out(p) for p in rows]


@router.get("/my/leads", response_model=dict)
async def my_leads(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Leads on the creator's own products (genuine events only)."""
    my_ids = select(Product.id).where(Product.creator_id == user.id)
    rows = (
        await db.execute(
            select(CommerceLead, Product.title)
            .join(Product, Product.id == CommerceLead.product_id)
            .where(CommerceLead.product_id.in_(my_ids))
            .order_by(desc(CommerceLead.created_at)).limit(200)
        )
    ).all()
    return {
        "leads": [
            {"id": str(lead.id), "product_id": str(lead.product_id),
             "product_title": title, "source": lead.source,
             "status": lead.status,
             "created_at": lead.created_at.isoformat() if lead.created_at else ""}
            for lead, title in rows
        ],
        "total": len(rows),
    }


@router.post("/orders", response_model=dict, status_code=201)
async def create_commerce_order(
    body: OrderIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Start a purchase: creates the CommerceOrder (status="created").

    Live provider checkout is NOT wired yet — the response carries
    ``checkout_ready: false`` with next-step guidance. When the billing
    "commerce" kind ships, the client will call POST /billing/orders with
    metadata {"commerce_order_id": id}; the verify hook will then link the
    Transaction and flip this order to "paid". No money moves here.
    """
    from app.services.payments.base import supported_providers

    product = await _get_product(db, _parse_uuid(body.product_id))
    if not product.is_active:
        raise HTTPException(404, "Product not found")
    if str(product.creator_id) == str(user.id):
        raise HTTPException(400, "You can't buy your own product")
    if product.stock_qty <= 0:
        raise HTTPException(400, "Out of stock")
    provider = (body.provider or "").lower()
    if provider and provider not in supported_providers():
        raise HTTPException(400, f"Unsupported provider: {body.provider}")
    order = CommerceOrder(
        product_id=product.id,
        buyer_id=user.id,
        amount_cents=product.price_cents,
        currency=product.currency,
        payment_provider=provider,
        status="created",
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)
    return {
        "order_id": str(order.id),
        "product_id": str(product.id),
        "amount_cents": order.amount_cents,
        "price_display": _price_display(order.amount_cents, order.currency),
        "currency": order.currency,
        "status": order.status,
        "checkout_ready": False,
        "message": ("Checkout via PayPal / Payoneer / Google Pay is being "
                    "connected. Your order is saved — you'll be notified "
                    "when payment opens."),
    }


@router.get("/orders/{order_id}", response_model=dict)
async def order_status(
    order_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(CommerceOrder).where(CommerceOrder.id == _parse_uuid(order_id)))
    order = res.scalar_one_or_none()
    if order is None:
        raise HTTPException(404, "Order not found")
    product = await _get_product(db, order.product_id)
    if str(order.buyer_id) != str(user.id) and \
            str(product.creator_id) != str(user.id):
        raise HTTPException(403, "Not your order")
    return {
        "order_id": str(order.id),
        "product": _to_out(product).model_dump(),
        "amount_cents": order.amount_cents,
        "price_display": _price_display(order.amount_cents, order.currency),
        "currency": order.currency,
        "status": order.status,
        "payment_provider": order.payment_provider,
        "checkout_ready": False,
    }


async def link_transaction_to_order(
    db: AsyncSession,
    order_id: uuid.UUID,
    transaction_id: uuid.UUID,
    provider_txn_id: str = "",
) -> CommerceOrder | None:
    """Hook for the billing verify flow. When billing ships kind="commerce",
    its verify endpoint should (lazily) import this and call it after a
    verified "completed" payment:

        from app.routers.commerce import link_transaction_to_order
        await link_transaction_to_order(db, commerce_order_id, transaction.id,
                                        provider_ref)

    Links the Transaction, flips the order to "paid", and decrements stock.
    Returns the updated order, or None if the order id is unknown.
    """
    res = await db.execute(
        select(CommerceOrder).where(CommerceOrder.id == order_id))
    order = res.scalar_one_or_none()
    if order is None:
        return None
    if order.status == "paid":
        return order  # idempotent — webhooks/retries can't double-apply
    order.transaction_id = transaction_id
    order.provider_txn_id = provider_txn_id
    order.status = "paid"
    product = await _get_product(db, order.product_id)
    if product.stock_qty > 0:
        product.stock_qty -= 1
    await db.commit()
    await db.refresh(order)
    return order


# ---------------------------------------------------------------------------
# AI Curator (daily affiliate product curation)
# ---------------------------------------------------------------------------

class CurateProductIn(BaseModel):
    """One product found by the AI curator. ASIN is the Amazon product ID
    (10-char alphanumeric, e.g. B08N5WRWNW). The affiliate URL is built
    server-side from the ASIN + partner tag — the curator never invents URLs."""
    asin: str = Field(..., min_length=10, max_length=10, pattern=r"^[A-Z0-9]{10}$")
    title: str = Field(..., min_length=1, max_length=200)
    description: str = Field(default="", max_length=5000)
    category: str = Field(default="all", max_length=64)
    # price_cents=0 means "price not verified — check on Amazon".
    # The Shop UI shows "Check price on Amazon" instead of $0.00.
    price_cents: int = Field(default=0, ge=0, le=100_000_000)
    currency: str = Field(default="USD", max_length=8)
    image_urls: list[str] = Field(default_factory=list, max_length=10)
    # Trend research (honest, from real signals only — never invented):
    # 0-100 score + short note like "amazon bestseller #3 in LED strips".
    # 0 = not scored. On duplicates the score is refreshed (re-validation).
    trend_score: int = Field(default=0, ge=0, le=100)
    trend_signals: str = Field(default="", max_length=500)


class CurateIn(BaseModel):
    products: list[CurateProductIn] = Field(..., min_length=1, max_length=25)
    # Products are attributed to this account (Hafiz's — his affiliate tag).
    creator_email: str = Field(..., max_length=320)


def _check_curator_token(request_token: str) -> None:
    """Service-to-service auth for the AI curator. Token lives in the
    Secure Vault / env, never in code or chat."""
    import os
    expected = os.environ.get("VIRELLO_CURATOR_TOKEN", "")
    if not expected or not request_token or not secrets.compare_digest(request_token, expected):
        raise HTTPException(401, "Invalid curator token")


@router.post("/wishlist", response_model=dict, status_code=201)
async def toggle_wishlist(
    payload: dict,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Save or remove a product from the user's wishlist (heart button)."""
    pid = payload.get("product_id")
    saved = bool(payload.get("saved", True))
    if not pid:
        raise HTTPException(status_code=400, detail="product_id required")
    try:
        pid_u = uuid.UUID(str(pid))
    except ValueError:
        raise HTTPException(status_code=400, detail="invalid product_id")
    existing = (await db.execute(
        select(WishlistItem).where(
            WishlistItem.user_id == user.id,
            WishlistItem.product_id == pid_u,
        )
    )).scalars().first()
    if saved and not existing:
        db.add(WishlistItem(user_id=user.id, product_id=pid_u))
        await db.commit()
    elif not saved and existing:
        await db.delete(existing)
        await db.commit()
    return {"saved": saved, "product_id": str(pid)}


@router.post("/products/gallery", response_model=dict)
async def update_product_gallery(
    payload: dict,
    x_curator_token: str | None = Header(default=None, alias="X-Curator-Token"),
    db: AsyncSession = Depends(get_db),
):
    """Update a product's gallery images (AI-generated angles).
    Auth: X-Curator-Token header. Body: {"asin": "...", "image_urls": [...]}.
    Replaces image_urls entirely (gallery backfill)."""
    _check_curator_token(x_curator_token or "")
    asin = (payload.get("asin") or "").strip().upper()
    image_urls = [u.strip() for u in (payload.get("image_urls") or []) if u.strip()][:10]
    if not asin or not image_urls:
        raise HTTPException(status_code=400, detail="asin and image_urls required")
    from app.services.affiliate.amazon import AmazonAffiliateProvider
    provider = AmazonAffiliateProvider()
    affiliate_url = provider.build_affiliate_url(asin)
    existing = (
        await db.execute(select(Product).where(Product.affiliate_url == affiliate_url))
    ).scalar_one_or_none()
    if existing is None:
        raise HTTPException(status_code=404, detail=f"Product not found: {asin}")
    existing.image_urls = image_urls
    await db.commit()
    return {"asin": asin, "product_id": str(existing.id),
            "image_urls": image_urls, "count": len(image_urls)}


@router.post("/products/gallery-upload", response_model=dict, status_code=201)
async def upload_gallery_image(
    file: UploadFile = File(...),
    asin: str = Form(""),
    slot: str = Form("main"),
    suffix: str = Form(""),
    x_curator_token: str | None = Header(default=None, alias="X-Curator-Token"),
):
    """Upload one gallery image to Cloudinary (replaces the old git-push
    flow — new images are never committed to the repo anymore).
    Auth: X-Curator-Token header. Multipart: file (JPEG or PNG), asin, slot
    (main|angle2|angle3), optional suffix (e.g. "_nobg" for transparent
    background-removed images). Returns {"url": "<live cloudinary url>"} —
    the URL is usable immediately, no deploy needed."""
    _check_curator_token(x_curator_token or "")
    asin = (asin or "").strip().upper()
    slot = (slot or "").strip().lower()
    suffix = (suffix or "").strip()
    if not asin or not re.fullmatch(r"[A-Z0-9]{10}", asin):
        raise HTTPException(status_code=400, detail="valid 10-char asin required")
    if slot not in ("main", "angle2", "angle3"):
        raise HTTPException(status_code=400, detail="slot must be main|angle2|angle3")
    if suffix and not re.fullmatch(r"[A-Za-z0-9_]{1,20}", suffix):
        raise HTTPException(status_code=400, detail="invalid suffix")
    data = await file.read()
    is_png = data.startswith(b"\x89PNG\r\n\x1a\n")
    from app.curation.gallery import check_jpeg
    if is_png:
        # transparent background-removed image: basic PNG integrity check
        from PIL import Image
        import io
        try:
            with Image.open(io.BytesIO(data)) as im:
                im.verify()
            with Image.open(io.BytesIO(data)) as im:
                w, h = im.size
                if im.mode not in ("RGBA", "LA", "PA", "RGB", "P"):
                    raise ValueError("unsupported mode")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"invalid PNG: {type(e).__name__}")
        if min(w, h) < 300:
            raise HTTPException(status_code=400, detail=f"dimensions too small ({w}x{h})")
        content_type = "image/png"
    else:
        ok, why = check_jpeg(data)
        if not ok:
            raise HTTPException(status_code=400, detail=f"invalid JPEG: {why}")
        content_type = "image/jpeg"
    from app.curation.cloudinary_store import cloudinary_enabled, upload_image
    if not cloudinary_enabled():
        raise HTTPException(status_code=503,
                            detail="cloudinary not configured on server")
    try:
        url = await upload_image(data, f"{asin}_{slot}{suffix}",
                                 content_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e)[:200])
    return {"asin": asin, "slot": slot, "url": url}


@router.get("/wishlist", response_model=list)
async def get_wishlist(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """User's wishlisted products (for future wishlist tab)."""
    rows = (await db.execute(
        select(WishlistItem).where(WishlistItem.user_id == user.id)
        .order_by(WishlistItem.created_at.desc())
    )).scalars().all()
    return [{"product_id": str(w.product_id),
             "created_at": w.created_at.isoformat() if w.created_at else None}
            for w in rows]


@router.post("/products/curate", response_model=dict, status_code=201)
async def curate_products(
    body: CurateIn,
    db: AsyncSession = Depends(get_db),
    x_curator_token: str | None = Header(default=None, alias="X-Curator-Token"),
):
    """Curator bulk-imports affiliate products.

    Auth: X-Curator-Token header (service token, not user JWT).
    For each product: validates ASIN, builds the affiliate URL server-side
    from the partner tag, creates the Product (is_affiliate=true) + ProductPage.
    Skips ASINs already in the catalog (idempotent — safe to re-run daily).

    Listing itself goes through app.curation.service.curate_product — the
    same function the autonomous hourly loop uses, so the API and the loop
    can never drift apart.
    """
    _check_curator_token(x_curator_token or "")

    from app.services.affiliate.amazon import AmazonAffiliateProvider
    provider = AmazonAffiliateProvider()
    if not provider.can_build_links():
        raise HTTPException(503, "Amazon partner tag not configured")

    # Attribute to the curator account (Hafiz's).
    res = await db.execute(select(User).where(User.email == body.creator_email.strip().lower()))
    creator = res.scalar_one_or_none()
    if creator is None:
        raise HTTPException(404, f"Creator account not found: {body.creator_email}")

    from app.curation.service import curate_product
    created: list[dict] = []
    skipped: list[str] = []
    for item in body.products:
        out = await curate_product(
            db,
            asin=item.asin,
            title=item.title,
            description=item.description,
            category=item.category,
            price_cents=item.price_cents,
            currency=item.currency,
            image_urls=item.image_urls,
            creator=creator,
            trend_score=item.trend_score,
            trend_signals=item.trend_signals,
        )
        if out["skipped"]:
            skipped.append(out["asin"])
        else:
            entry: dict = {"asin": out["asin"],
                           "product_id": out["product_id"],
                           "title": out["title"]}
            if out.get("updated"):
                entry["updated"] = out["updated"]
            created.append(entry)
    await db.commit()
    return {
        "created": created,
        "skipped_duplicate": skipped,
        "total_created": len(created),
        "disclosure": "All products carry the affiliate disclosure in the Shop UI.",
    }
