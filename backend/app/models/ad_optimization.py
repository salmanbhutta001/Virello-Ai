"""Phase 3 ad platform models: AI Distribution & Optimization Agent.

The autonomous closed loop: serve → genuine events → measure → optimize →
keep distributing. Every adjustment is explainable and auditable.

Privacy by design (same contract as Phases 1–2):
- Optimization consumes ONLY aggregate counts from ``ad_impressions`` —
  genuine measured events. No private user data is ever read or stored.
- Per-user segment membership is still never stored.

Honesty:
- All optimizer output is estimated guidance, never guaranteed outcomes.
- ``AdDecision`` rows (agent="optimizer") record every adjustment with
  reasons, before/after metrics, and the disclaimer — nothing is a black box.
- The optimizer can NEVER raise spend: it only reweights distribution
  within the advertiser-approved budget and daily caps.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum

from sqlalchemy import JSON, DateTime, Enum as SAEnum, Float, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class OptimizationRunStatus(str, Enum):
    completed = "completed"
    safety_paused = "safety_paused"  # suspicious traffic → auto-paused
    skipped = "skipped"              # nothing to optimize (not deliverable / no data)
    failed = "failed"


class VariantStatus(str, Enum):
    active = "active"
    paused = "paused"


class AdOptimizationRun(Base):
    """One optimizer pass over a campaign: what was measured, what changed,
    and why. ``summary`` holds {segments_adjusted, variants_tested,
    placements_compared, decisions, triggered_by, window}."""

    __tablename__ = "ad_optimization_runs"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    status: Mapped[OptimizationRunStatus] = mapped_column(
        SAEnum(OptimizationRunStatus), default=OptimizationRunStatus.completed,
        index=True)
    triggered_by: Mapped[str] = mapped_column(
        String(32), default="manual")  # manual | scheduler
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
    summary: Mapped[dict] = mapped_column(JSON, default=dict)


class AdSegmentWeight(Base):
    """Per-(campaign, segment) distribution weight plus the performance
    snapshot the last optimization pass saw. Additive only — serving reads
    these weights; the optimizer rewrites them each pass."""

    __tablename__ = "ad_segment_weights"
    __table_args__ = (
        UniqueConstraint("campaign_id", "segment_id",
                         name="uq_ad_segment_weight"),
    )
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    segment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("audience_segments.id"))
    weight: Mapped[float] = mapped_column(Float, default=1.0)
    # last measured snapshot (genuine events only)
    impressions: Mapped[int] = mapped_column(Integer, default=0)
    views: Mapped[int] = mapped_column(Integer, default=0)
    engagements: Mapped[int] = mapped_column(Integer, default=0)
    engagement_rate: Mapped[float] = mapped_column(Float, default=0.0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class AdVariant(Base):
    """Ad creative variant (hook/caption/hashtag alternatives) linked to a
    campaign, tested in deterministic weighted rotation like GrowthVariant.
    The advertiser's original is ALWAYS the baseline (is_original)."""

    __tablename__ = "ad_variants"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    label: Mapped[str] = mapped_column(String(128), default="")
    kind: Mapped[str] = mapped_column(String(32), default="caption")
    # hook | caption | hashtag
    content: Mapped[dict] = mapped_column(JSON, default=dict)
    # {"hook": ..., "caption": ..., "hashtags": [...]}
    rationale: Mapped[str] = mapped_column(Text, default="")
    weight: Mapped[float] = mapped_column(Float, default=1.0)
    status: Mapped[VariantStatus] = mapped_column(
        SAEnum(VariantStatus), default=VariantStatus.active)
    is_original: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
