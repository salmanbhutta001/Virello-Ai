"""Phase 2 ad delivery models: Sponsored Discovery / Ad Network.

Privacy by design (same contract as Phase 1):
- Segment membership is STILL never stored — it is computed at serve time
  from the user's declared opt-in interests and language.
- ``AdImpression.viewer_user_id`` is recorded ONLY when the event is genuinely
  measurable (an authenticated user actually rendered / interacted with the
  unit through the events API). It is nullable, and it is never fabricated.
- This table is the single source of truth for delivery measurement: spend
  is derived only from recorded genuine events, never from estimates.

Honesty:
- Every served ad unit carries ``is_sponsored=True`` plus a visible
  "Sponsored" label; organic results are never labeled, sponsored units are
  never presented as organic.
- ``AdBudget.spent`` is simulated accounting from priced genuine events (see
  PRICING in app.services.ad_distribution) — NOT real money movement. Real
  charging still needs a payment provider integration (PayPal/Payoneer/
  Google Pay), which Phase 2 does not claim to do.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum

from sqlalchemy import JSON, DateTime, Enum as SAEnum, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class PlacementType(str, Enum):
    sponsored_discovery = "sponsored_discovery"
    recommended_posts = "recommended_posts"
    native_promo = "native_promo"
    feed = "feed"


class PlacementStatus(str, Enum):
    active = "active"
    paused = "paused"


class AdEventType(str, Enum):
    impression = "impression"  # unit was genuinely rendered on the user's screen
    view = "view"              # user opened / lingered on the unit
    like = "like"
    save = "save"
    visit = "visit"            # tap-through to the destination
    follow = "follow"
    click = "click"            # any other tap on the unit's CTA


class AdPlacement(Base):
    """One place where a campaign's sponsored unit can be served."""

    __tablename__ = "ad_placements"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    placement_type: Mapped[PlacementType] = mapped_column(
        SAEnum(PlacementType), default=PlacementType.sponsored_discovery)
    status: Mapped[PlacementStatus] = mapped_column(
        SAEnum(PlacementStatus), default=PlacementStatus.active)
    weight: Mapped[float] = mapped_column(Float, default=1.0)  # serve priority
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class AdImpression(Base):
    """One genuine delivery event. ONLY recorded when it really happened —
    a serve response is not an impression; the client must confirm rendering
    through the events API. Duplicate confirmations inside the dedupe window
    are rejected, never double-counted."""

    __tablename__ = "ad_impressions"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    placement_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("ad_placements.id"), nullable=True)
    segment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("audience_segments.id"), nullable=True)
    # the matched segment at serve time (explainability), not membership
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("ad_variants.id"), nullable=True)
    # Phase 3: which creative variant was displayed (per-variant attribution).
    # Nullable — only recorded when the client confirms which variant rendered.
    viewer_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id"), nullable=True, index=True)
    # nullable: only recorded when genuinely measurable, never fabricated
    event_type: Mapped[AdEventType] = mapped_column(
        SAEnum(AdEventType), index=True)
    # ISO code of the served creative's language — recorded only when
    # genuinely known, never inferred per-user.
    language: Mapped[str | None] = mapped_column(String(16), nullable=True,
                                                 default=None)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    meta: Mapped[dict] = mapped_column(JSON, default=dict)


class AdBudget(Base):
    """Pacing + spend state for one campaign. ``spent`` is derived from priced
    genuine events only (see PRICING in ad_distribution); it can never exceed
    ``total_budget`` — serving hard-stops first."""

    __tablename__ = "ad_budgets"
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), primary_key=True)
    total_budget: Mapped[float] = mapped_column(Float, default=0.0)
    # advertiser-approved cap, set at launch
    spent: Mapped[float] = mapped_column(Float, default=0.0)
    daily_cap: Mapped[float] = mapped_column(Float, default=0.0)
    # pacing: total_budget / duration_days
    pacing_state: Mapped[dict] = mapped_column(JSON, default=dict)
    # {"date": "YYYY-MM-DD", "spent_today": float}
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
