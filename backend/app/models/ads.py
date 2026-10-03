"""Phase 1 ad platform models: Audience Intelligence + AI Campaign Builder.

Privacy by design:
- AudienceSegment definitions use ONLY legitimate signals: discovery
  opt-in topic taxonomy, declared language, content categories/hashtags from
  the content itself, creator/category affinity from first-party app data,
  and aggregate/anonymized counts.
- Per-user segment membership is NEVER stored — it is computed at match time
  from opt-in data. There is no membership table here, on purpose.
- Segment rules must declare which signals formed them (signals_used).

Honesty:
- size_estimate and estimate fields are estimates, never guarantees. Every
  API response carrying them must include a disclaimer.
- ad_decisions mirrors the GrowthDecision audit pattern: every agent action
  with reasons is persisted so nothing is a black box.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum

from sqlalchemy import JSON, DateTime, Enum as SAEnum, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class AdObjective(str, Enum):
    views = "views"
    engagement = "engagement"
    followers = "followers"
    leads = "leads"
    sales = "sales"


class AdCampaignStatus(str, Enum):
    draft = "draft"
    pending_approval = "pending_approval"
    approved = "approved"
    rejected = "rejected"
    active = "active"
    paused = "paused"
    completed = "completed"


class AudienceSegment(Base):
    """A reusable audience definition built from legitimate signals only.

    ``rule`` holds the matching criteria, e.g.
    {"topics": ["technology"], "languages": ["en"], "hashtags": ["ai"],
     "categories": ["video"]} — never any user's private data.
    ``signals_used`` declares which legitimate signals formed the segment
    (explainability), e.g. ["opt_in_topics", "taxonomy", "declared_language"].
    ``size_estimate`` is a rough estimate of opted-in users, not a guarantee.
    """

    __tablename__ = "audience_segments"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String(128), default="")
    description: Mapped[str] = mapped_column(String(1024), default="")
    rule: Mapped[dict] = mapped_column(JSON, default=dict)
    signals_used: Mapped[list] = mapped_column(JSON, default=list)
    size_estimate: Mapped[int] = mapped_column(Integer, default=0)
    languages: Mapped[list] = mapped_column(JSON, default=list)
    topics: Mapped[list] = mapped_column(JSON, default=list)
    # Multilingual graph: ISO codes the segment's aggregate signals cover
    # (declared/aggregate only), and canonical concept slugs for
    # cross-language matching.
    language_coverage: Mapped[list] = mapped_column(JSON, default=list)
    concept_slugs: Mapped[list] = mapped_column(JSON, default=list)
    is_active: Mapped[bool] = mapped_column(default=True)
    created_by: Mapped[str] = mapped_column(String(32), default="system")
    # admin | system
    explanation: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    # --- Multi-source audience-intelligence graph (hierarchical taxonomy) ---
    # path: e.g. "Home & Kitchen > Kitchen Towels > Cooking Enthusiasts > Pakistan"
    path: Mapped[str] = mapped_column(String(512), default="")
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("audience_segments.id"), nullable=True, default=None)
    # ISO country code focus ("" = global). Declared, never inferred per-user.
    geography: Mapped[str] = mapped_column(String(8), default="")
    # [{source, contribution}] — which connectors formed this segment.
    source_breakdown: Mapped[list] = mapped_column(JSON, default=list)
    # 0..1 aggregate confidence from source confidences.
    confidence: Mapped[float] = mapped_column(Float, default=0.5)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now())


class AdCampaign(Base):
    """An advertiser's AI-assisted campaign draft. NOTHING launches without
    the advertiser's explicit approval (status moves draft → pending_approval
    → approved). ``active`` is not reachable via the public API in Phase 1."""

    __tablename__ = "ad_campaigns"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), index=True)
    objective: Mapped[AdObjective] = mapped_column(
        SAEnum(AdObjective), default=AdObjective.views)
    content_ref: Mapped[str] = mapped_column(Text, default="")
    # original URL or pasted post text (truncated)
    content_signals: Mapped[dict] = mapped_column(JSON, default=dict)
    # cached analysis: topics, hashtags, categories, language, entities, score
    topics: Mapped[list] = mapped_column(JSON, default=list)
    languages: Mapped[list] = mapped_column(JSON, default=list)
    # Multilingual targeting: single | multiple | all_relevant.
    # all_relevant = AI may match any language audience the content is
    # relevant to, within the approved budget/duration.
    language_targeting_mode: Mapped[str] = mapped_column(
        String(16), default="single")
    target_languages: Mapped[list] = mapped_column(JSON, default=list)
    # [{code, reason}] from the expansion recommender — suggestions with
    # explanations, never guarantees.
    suggested_languages: Mapped[list] = mapped_column(JSON, default=list)
    # Geography targeting: ai_recommended | worldwide | custom.
    # ai_recommended = AI suggests countries from post language + matched
    # segment geography (explainable, in suggested_geography); the
    # advertiser still approves the final selection before any spend.
    geo_mode: Mapped[str] = mapped_column(String(16), default="ai_recommended")
    # Effective ISO country codes for ai_recommended/custom (worldwide → []).
    geo_countries: Mapped[list] = mapped_column(JSON, default=list)
    # {"countries": [...], "reasons": [...]} — the AI suggestion with
    # explanations, never guarantees.
    suggested_geography: Mapped[dict] = mapped_column(JSON, default=dict)
    segment_ids: Mapped[list] = mapped_column(JSON, default=list)
    # chosen audience segment ids (as strings)
    budget: Mapped[float] = mapped_column(Float, default=0.0)  # user-approved
    duration_days: Mapped[int] = mapped_column(Integer, default=7)
    freq_cap: Mapped[int] = mapped_column(Integer, default=3, server_default="3")
    # Phase 2: max genuine impressions per user per campaign (lifetime).
    # Enforced at serve time; the advertiser can tighten it, never loosen
    # honesty constraints.
    status: Mapped[AdCampaignStatus] = mapped_column(
        SAEnum(AdCampaignStatus), default=AdCampaignStatus.draft, index=True)
    # Campaign plan: "free" | "paid".
    #   free = Free Grow: worldwide audience only, zero budget, no spend
    #          ever accrues (organic discovery delivery).
    #   paid = Paid Boost: advertiser-approved budget, geo targeting
    #          (AI-recommended / worldwide / custom) available.
    # Existing campaigns backfill to "paid" (they were all budgeted).
    plan: Mapped[str] = mapped_column(String(8), default="paid", index=True)
    # Paid Boost package id (e.g. "growth") — null for Free Grow and for
    # legacy/custom-budget paid campaigns. The package price/duration are
    # copied into budget/duration_days at build time; this keeps the label.
    package_id: Mapped[str | None] = mapped_column(String(32), nullable=True,
                                                   default=None)
    # Package payment state for Paid Boost: "unpaid" | "paid".
    # Set to "paid" only by POST /api/v1/billing/play/verify (or the Amazon
    # equivalent) after the store confirms the matching ad-package product.
    # The app NEVER marks this locally — server verification is mandatory.
    # Free Grow campaigns stay "unpaid" by design (nothing to pay).
    payment_status: Mapped[str] = mapped_column(String(16), default="unpaid")
    estimate: Mapped[dict] = mapped_column(JSON, default=dict)
    # {estimated_reach_low, estimated_reach_high, disclaimer: "estimate — not a guarantee"}
    ai_provider: Mapped[str] = mapped_column(String(64), default="")
    ai_model: Mapped[str] = mapped_column(String(128), default="")
    dev: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ContentSignal(Base):
    """Cache of content signals keyed by hash of the post content/URL.

    Signals are derived from the post itself + the analysis engine — never
    from any user's private data. TTL-style reuse avoids re-analysis.
    """

    __tablename__ = "content_signals"
    post_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    topics: Mapped[list] = mapped_column(JSON, default=list)
    hashtags: Mapped[list] = mapped_column(JSON, default=list)
    categories: Mapped[list] = mapped_column(JSON, default=list)
    language: Mapped[str] = mapped_column(String(8), default="unknown")
    # Canonical concept slugs found in any language (shared IDs).
    concepts: Mapped[list] = mapped_column(JSON, default=list)
    entities: Mapped[list] = mapped_column(JSON, default=list)
    analysis_score: Mapped[float] = mapped_column(Float, default=0.0)
    # transparent 0-100 packaging score from the analysis engine
    extracted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class AdDecision(Base):
    """Audit trail mirroring GrowthDecision: every ad-agent decision with its
    reasons, metrics, and disclaimer. Nothing the platform does is a black box.
    Agents: audience | content | matching | builder | system."""

    __tablename__ = "ad_decisions"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ad_campaigns.id"), index=True)
    agent: Mapped[str] = mapped_column(String(32), index=True)
    action: Mapped[str] = mapped_column(String(64), default="")
    details: Mapped[dict] = mapped_column(JSON, default=dict)
    # {reasons[], metrics{}, disclaimer}
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
