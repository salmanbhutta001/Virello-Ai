"""Audience-intelligence source signal cache.

Stores AGGREGATE connector outputs so the segment graph can be rebuilt
without re-hitting rate-limited APIs. Rows are per (source, topic, geography)
— never per user. Volume fields hold ONLY real source numbers (or NULL).
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class AudienceSourceSignal(Base):
    """Cached aggregate signal from one connector fetch."""
    __tablename__ = "audience_source_signals"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True,
                                         default=_uuid)
    source: Mapped[str] = mapped_column(String(64), index=True)
    topic: Mapped[str] = mapped_column(String(128), index=True)
    keywords: Mapped[list] = mapped_column(JSON, default=list)
    geography: Mapped[str] = mapped_column(String(8), default="")
    language: Mapped[str] = mapped_column(String(8), default="")
    # Real source number only; NULL = "volume unavailable".
    volume_hint: Mapped[float | None] = mapped_column(Float, nullable=True)
    volume_label: Mapped[str] = mapped_column(
        String(512), default="volume unavailable")
    trend_direction: Mapped[str] = mapped_column(String(16), default="unknown")
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    raw_note: Mapped[str] = mapped_column(Text, default="")
