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
