"""AI Growth Engine models — the self-optimizing distribution loop.

analyze → audience match → distribute → measure → learn → optimize …

Every agent decision is persisted in `growth_decisions` with its reasons, so
the whole loop is explainable and auditable. All engagement measured here is
genuine discovery interaction (views/saves/visits/dismissals by real users);
nothing artificial is ever created or counted.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class GrowthLoop(Base):
    """One autonomous growth loop per campaign."""

    __tablename__ = "growth_loops"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("campaigns.id"), unique=True, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    # running | paused | awaiting_approval | completed | stopped
    status: Mapped[str] = mapped_column(String(24), default="awaiting_approval",
                                        index=True)
    round: Mapped[int] = mapped_column(Integer, default=0)  # completed rounds
    config: Mapped[dict] = mapped_column(JSON, default=dict)
    # {round_hours, explore_floor, min_views, max_variants, auto_apply_variants}
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class GrowthSegment(Base):
    """An audience slice the engine distributes to: topics × languages × markets."""

    __tablename__ = "growth_segments"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    loop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("growth_loops.id"), index=True)
    name: Mapped[str] = mapped_column(String(128), default="")
    topics: Mapped[list] = mapped_column(JSON, default=list)
    languages: Mapped[list] = mapped_column(JSON, default=list)
    markets: Mapped[list] = mapped_column(JSON, default=list)
    weight: Mapped[float] = mapped_column(Float, default=1.0)  # distribution multiplier
    prior_score: Mapped[float] = mapped_column(Float, default=0.5)
    status: Mapped[str] = mapped_column(String(16), default="active")  # active | paused
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class GrowthVariant(Base):
    """A content variation the engine rotates in the discovery feed
    (hook/caption/hashtag/posting-window suggestions). `is_original` marks the
    creator's own version; others are AI suggestions, applied only with the
    creator's opt-in (auto_apply_variants) or kept as suggestions."""

    __tablename__ = "growth_variants"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    loop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("growth_loops.id"), index=True)
    label: Mapped[str] = mapped_column(String(128), default="")
    kind: Mapped[str] = mapped_column(String(32), default="caption")
    # caption | hashtags | thumbnail_brief | posting_window
    content: Mapped[dict] = mapped_column(JSON, default=dict)
    # {title, caption, hooks[], hashtags[], thumbnail_brief, posting_windows[]}
    rationale: Mapped[str] = mapped_column(String(1024), default="")
    weight: Mapped[float] = mapped_column(Float, default=1.0)  # rotation weight
    is_original: Mapped[bool] = mapped_column(default=False)
    status: Mapped[str] = mapped_column(String(16), default="active")  # active | paused
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class GrowthRound(Base):
    """One measure→learn→optimize cycle."""

    __tablename__ = "growth_rounds"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    loop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("growth_loops.id"), index=True)
    number: Mapped[int] = mapped_column(Integer, default=1)
    summary: Mapped[dict] = mapped_column(JSON, default=dict)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class GrowthObservation(Base):
    """Aggregated genuine interactions for one round, per segment/variant."""

    __tablename__ = "growth_observations"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    loop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("growth_loops.id"), index=True)
    round: Mapped[int] = mapped_column(Integer, default=1)
    segment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("growth_segments.id"), nullable=True)
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("growth_variants.id"), nullable=True)
    views: Mapped[int] = mapped_column(Integer, default=0)
    saves: Mapped[int] = mapped_column(Integer, default=0)
    visits: Mapped[int] = mapped_column(Integer, default=0)
    dismissals: Mapped[int] = mapped_column(Integer, default=0)
    # fractional attribution may produce non-integers; stored rounded with note
    attribution: Mapped[str] = mapped_column(String(32), default="direct")
    # direct (variant) | fractional (segment via user interests)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class GrowthDecision(Base):
    """The audit trail: every agent action with its reasons. Nothing the engine
    does is a black box."""

    __tablename__ = "growth_decisions"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    loop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("growth_loops.id"), index=True)
    round: Mapped[int] = mapped_column(Integer, default=0)
    agent: Mapped[str] = mapped_column(String(32), index=True)
    # audience | content | distribution | performance | learning | system
    action: Mapped[str] = mapped_column(String(64), default="")
    details: Mapped[dict] = mapped_column(JSON, default=dict)
    # {reasons[], metrics{}, before{}, after{}, disclaimer}
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
