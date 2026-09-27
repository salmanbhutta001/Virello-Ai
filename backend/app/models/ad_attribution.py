"""Phase 4 ad platform models: Conversion Attribution (future-ready).

Privacy by design (same contract as Phases 1–3):
- Attribution links events via OPAQUE click IDs (random server-side tokens).
  A click id carries campaign/placement/segment/variant ids — never any
  private user data, never a user id. Advertisers only ever see aggregate
  conversion counts and advertiser-reported/measured revenue; they never
  learn who clicked.
- ``ad_landing_events.value`` is advertiser-reported/measured revenue (from
  their pixel/webhook/api). It is labeled as such everywhere — it is NOT
  platform-verified sales.

Honesty:
- Attribution model is last-click for now (``attributed_model="last_click"``
  on every conversion). Multi-touch models are future work — the schema is
  ready for them (the column is a plain string, not a boolean).
- Every attribution writes an AdDecision audit row (agent="attribution")
  with reasons, so no conversion is a black box.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum

from sqlalchemy import JSON, DateTime, Enum as SAEnum, Float, ForeignKey, String, func, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class LandingEventType(str, Enum):
    """Landing-page funnel events reported by the advertiser's pixel/webhook/
    api integration. Only ``lead``/``purchase``/``signup``/``custom`` count
    as conversions; ``page_view`` is a landing signal only."""
    page_view = "page_view"
    lead = "lead"
    purchase = "purchase"
    signup = "signup"
    custom = "custom"


class LandingEventSource(str, Enum):
    """Where a landing event was reported from."""
    pixel = "pixel"        # advertiser's client-side tracking pixel
    webhook = "webhook"    # advertiser server-to-server webhook
    api = "api"            # advertiser's direct API call


class AdClickId(Base):
    """One opaque click token minted server-side when a user taps an ad.

    The id is a random token (never sequential, never derivable) mapped to
    the campaign/placement/segment/variant chain. Clients append it to
    landing URLs as ``?virello_click_id=<token>`` so later landing events
    can be attributed back. It expires (TTL) — old tokens are rejected.
    No user id is stored here, ever."""

    __tablename__ = "ad_click_ids"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    # opaque token, e.g. secrets.token_hex(16)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    placement_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("ad_placements.id"), nullable=True)
    segment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("audience_segments.id"), nullable=True)
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("ad_variants.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False)


class AdLandingEvent(Base):
    """One landing-funnel event reported against a click id by the
    advertiser's integration (pixel / webhook / api).

    ``value`` is advertiser-reported/measured revenue for purchases — the
    platform records what the advertiser reports; it does NOT verify the
    sale happened. Idempotent on (click_id, event_type): a double-submitted
    pixel fires once, never double-counted."""

    __tablename__ = "ad_landing_events"
    __table_args__ = (
        UniqueConstraint("click_id", "event_type",
                         name="uq_ad_landing_event_click_type"),
    )
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    click_id: Mapped[str] = mapped_column(
        ForeignKey("ad_click_ids.id"), index=True)
    event_type: Mapped[LandingEventType] = mapped_column(
        SAEnum(LandingEventType), index=True)
    value: Mapped[float | None] = mapped_column(Float, nullable=True)
    # revenue for purchases; advertiser-reported, NOT platform-verified
    currency: Mapped[str] = mapped_column(String(8), default="USD")
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    meta: Mapped[dict] = mapped_column(JSON, default=dict)
    source: Mapped[LandingEventSource] = mapped_column(
        SAEnum(LandingEventSource), default=LandingEventSource.pixel,
        index=True)


class AdConversion(Base):
    """An attributed conversion: a landing event that counts as a campaign
    result under the last-click model. Linked back to the campaign/segment/
    variant via the click_id chain — no user data involved."""

    __tablename__ = "ad_conversions"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    click_id: Mapped[str | None] = mapped_column(
        ForeignKey("ad_click_ids.id"), nullable=True, index=True)
    # nullable: admin manual corrections can create a conversion without one
    segment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("audience_segments.id"), nullable=True)
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("ad_variants.id"), nullable=True)
    event_type: Mapped[str] = mapped_column(String(32), default="")
    # lead | purchase | signup | custom (subset of LandingEventType)
    value: Mapped[float | None] = mapped_column(Float, nullable=True)
    attributed_model: Mapped[str] = mapped_column(
        String(32), default="last_click", index=True)
    # future-ready: the column is a string so multi-touch models can land
    # here without a schema change.
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
