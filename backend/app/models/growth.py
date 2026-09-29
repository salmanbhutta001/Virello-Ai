"""Growth-domain models: post analysis cache + the organic discovery system.

The discovery system is Virello's own legitimate growth ecosystem:
real users opt in to topics they care about; the matcher surfaces
campaigns to genuinely interested audiences. No fake engagement —
every interaction recorded here is a real user action.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class PostAnalysis(Base):
    """Cached result of the post/link analysis engine (one row per URL)."""

    __tablename__ = "post_analyses"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    url: Mapped[str] = mapped_column(String(2048), unique=True, index=True)
    platform: Mapped[str] = mapped_column(String(32), default="unknown")
    fetch_level: Mapped[str] = mapped_column(String(16), default="minimal")
    # oembed | opengraph | minimal — how much real data we could fetch
    title: Mapped[str] = mapped_column(String(512), default="")
    author: Mapped[str] = mapped_column(String(256), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    thumbnail_url: Mapped[str] = mapped_column(String(2048), default="")
    media_type: Mapped[str] = mapped_column(String(16), default="unknown")
    language: Mapped[str] = mapped_column(String(8), default="unknown")
    # Full multilingual detection: {primary, script, confidence,
    # alternatives, is_mixed_language, contains_transliteration,
    # transliteration_variant, detection_uncertain, method_notes}.
    language_metadata: Mapped[dict] = mapped_column(JSON, default=dict)
    # Canonical concept slugs (cross-language topic IDs).
    concepts: Mapped[list] = mapped_column(JSON, default=list)
    hashtags: Mapped[list] = mapped_column(JSON, default=list)
    mentions: Mapped[list] = mapped_column(JSON, default=list)
    signals: Mapped[dict] = mapped_column(JSON, default=dict)  # extracted features
    score: Mapped[dict] = mapped_column(JSON, default=dict)  # transparent score breakdown
    analyzed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class Topic(Base):
    """Discovery taxonomy. Curated by Virello; localized names."""

    __tablename__ = "topics"
    slug: Mapped[str] = mapped_column(String(64), primary_key=True)
    name_en: Mapped[str] = mapped_column(String(128))
    name_ur: Mapped[str] = mapped_column(String(128), default="")
    active: Mapped[bool] = mapped_column(default=True)


class UserInterest(Base):
    """A user's opted-in discovery topics. Explicit opt-in only."""

    __tablename__ = "user_interests"
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), primary_key=True)
    topic_slug: Mapped[str] = mapped_column(ForeignKey("topics.slug"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DiscoveryPlacement(Base):
    """A campaign's entry in the discovery pool. Enters review, then
    approved/rejected. Only approved + live campaigns are matched."""

    __tablename__ = "discovery_placements"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("campaigns.id"), unique=True, index=True)
    topics: Mapped[list] = mapped_column(JSON, default=list)  # topic slugs
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    # pending | approved | rejected
    review_note: Mapped[str] = mapped_column(String(512), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class DiscoveryInteraction(Base):
    """Genuine user actions on discovery items. The ONLY engagement that
    counts in the discovery ecosystem — real people, real interest."""

    __tablename__ = "discovery_interactions"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    campaign_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("campaigns.id"), index=True)
    kind: Mapped[str] = mapped_column(String(16), index=True)
    # view | save | visit | dismiss | like
    variant_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("growth_variants.id"), nullable=True, index=True)
    # which Growth Engine content variant was displayed when the user acted
    # (echoed by the client from the feed item); null when no engine loop served it
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
