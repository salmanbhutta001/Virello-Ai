"""Trending Topics: curated trending topics with AI insights for the
Virello website and app.

Content rules:
- Summaries are ORIGINAL (never copied from Wikipedia/Google verbatim).
- Every topic carries an ai_insight: one line on how to create content
  about it — that's Virello's value-add.
- Sources are attributed via the ``source`` field.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class TrendingTopic(Base):
    """A trending topic with an original summary and AI content insight."""

    __tablename__ = "trending_topics"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(64), default="general", index=True)
    summary: Mapped[str] = mapped_column(Text, default="")
    ai_insight: Mapped[str] = mapped_column(Text, default="")
    image_url: Mapped[str] = mapped_column(String(500), default="")
    source: Mapped[str] = mapped_column(String(200), default="")
    trend_score: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False,
    )


class DiscoveryTrendsCache(Base):
    """Cached snapshot of the app's live trending feed.

    ``GET /api/v1/discovery/trending`` aggregates Wikimedia pageviews +
    Google News RSS per request. That live fetch (sequential per-article
    summary calls) routinely exceeds Vercel Hobby's 10s function limit,
    so the app's Trending screen saw an error and showed its empty
    state. This table holds one snapshot per (lang, geo): the endpoint
    serves the snapshot while it is fresh (TTL 1h) and only refetches
    when it expires — the refetch is parallelized to fit the budget.
    Payload is the full response dict (trends/sources/language/note)
    as JSON text; the app only reads ``trends``.
    """

    __tablename__ = "discovery_trends_cache"

    lang: Mapped[str] = mapped_column(String(8), primary_key=True)
    geo: Mapped[str] = mapped_column(String(8), primary_key=True)
    payload: Mapped[str] = mapped_column(Text, nullable=False, default="{}")
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
