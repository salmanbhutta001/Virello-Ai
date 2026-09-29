"""AI Commerce (Phase 4): product catalog, shareable product pages, leads,
orders.

Honesty rules:
- No fake products, prices, ratings, or sales anywhere. An empty catalog
  returns an empty list.
- Ratings/reviews do not exist yet — the API never invents them. The
  mobile UI shows a "New" badge instead of fabricated stars.
- Purchase money movement goes through the existing billing pipeline
  (POST /api/v1/billing/orders + /verify). A CommerceOrder is a
  commerce-domain record LINKED to a billing Transaction via
  ``transaction_id`` — it never moves money itself. See the docstring on
  CommerceOrder and the router's checkout notes.
- Sales attribution reuses the existing AdConversion model
  (models/ad_attribution.py) where a campaign drove the sale; organic
  shop sales are recorded on CommerceOrder only.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class Product(Base):
    """A creator-listed product. Created via POST /commerce/products by the
    signed-in creator (creator_id). Prices are stored as integer cents to
    avoid float rounding on money."""

    __tablename__ = "products"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    creator_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    price_cents: Mapped[int] = mapped_column(Integer, default=0)
    currency: Mapped[str] = mapped_column(String(8), default="USD")
    category: Mapped[str] = mapped_column(String(64), default="all", index=True)
    # Creator-supplied image URLs (JSON list). No upload pipeline yet —
    # creators paste hosted image URLs for now.
    image_urls: Mapped[list] = mapped_column(JSON, default=list)
    stock_qty: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    views: Mapped[int] = mapped_column(Integer, default=0)
    # --- Affiliate (e.g. Amazon Associates) ---
    # An affiliate product links OUT to the merchant; Virello never takes
    # payment for it. The detail UI must show the affiliate disclosure
    # ("Affiliate link — we may earn a commission") per FTC/Amazon rules.
    affiliate_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    affiliate_provider: Mapped[str | None] = mapped_column(
        String(32), nullable=True)  # e.g. "amazon"
    is_affiliate: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ProductPage(Base):
    """Shareable product page: /p/{slug} → GET /commerce/products/slug/{slug}.
    One row per product; views counted on each page hit."""

    __tablename__ = "product_pages"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    product_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("products.id"), unique=True, index=True)
    slug: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    views: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class CommerceLead(Base):
    """Genuine interest signal: a user tapped "I'm interested" on a product.
    Recorded as an event, never fabricated. Creators see their own leads."""

    __tablename__ = "commerce_leads"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    product_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("products.id"), index=True)
    # Nullable: anonymous visitors can leave interest via product page.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id"), nullable=True, index=True)
    source: Mapped[str] = mapped_column(String(32), default="shop")
    # shop | product_page | ask_virello | discovery ("Shop this")
    status: Mapped[str] = mapped_column(String(32), default="new")
    # new | contacted | converted | dropped
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class CommerceOrder(Base):
    """Commerce-domain order record. MONEY MOVEMENT HAPPENS ONLY IN THE
    BILLING PIPELINE (services/payments/*, models/billing.py Transaction).

    Flow: client calls POST /api/v1/billing/orders with
    kind="commerce" + metadata {"commerce_order_id": ...} →
    provider approval → POST /api/v1/billing/verify →
    on verified completion the billing hook links the Transaction here via
    ``transaction_id`` and flips status to "paid". This table never
    touches provider APIs directly."""

    __tablename__ = "commerce_orders"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    product_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("products.id"), index=True)
    buyer_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), index=True)
    amount_cents: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(8), default="USD")
    payment_provider: Mapped[str] = mapped_column(String(32), default="")
    # paypal | payoneer | google_pay (set when buyer picks a provider)
    provider_txn_id: Mapped[str] = mapped_column(String(128), default="")
    transaction_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("transactions.id"), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(32), default="created", index=True)
    # created | awaiting_payment | paid | failed | refunded | cancelled
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


# Displayed in the Shop UI category chips (matches Hafiz's reference).
PRODUCT_CATEGORIES = [
    "all", "tech", "fashion", "home", "fitness", "beauty",
    "men", "women", "sale", "best_sellers",
]


class WishlistItem(Base):
    """User's saved/wishlisted product (heart button on product detail)."""
    __tablename__ = "wishlist_items"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    product_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("products.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
