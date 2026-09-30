"""Curation tables: candidate queue + run history.

curation_candidates is the open feeder queue: the Amazon discovery adapter,
the existing hourly curator pipeline, or a human admin can insert rows
without code changes. The orchestrator consumes pending rows department by
department. curation_runs records every hourly run for the admin status
endpoint.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class CurationCandidate(Base):
    """One discovered product waiting to be listed. ASIN is unique —
    re-discovery of the same product updates the row instead of duplicating."""

    __tablename__ = "curation_candidates"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    asin: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(200))
    department: Mapped[str] = mapped_column(String(64), index=True)
    # Where it came from: "amazon_search" | "curator_agent" | "manual".
    source: Mapped[str] = mapped_column(String(32), default="amazon_search")
    # Verified main product photo URL (only ever a real photo, never generated).
    main_image_url: Mapped[str] = mapped_column(Text, default="")
    # pending → listed | skipped. listed = already in the catalog.
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    note: Mapped[str] = mapped_column(String(255), default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class CurationRun(Base):
    """One hourly orchestrator run. details JSON: per-department counts,
    ASINs created/skipped, gallery stats, errors."""

    __tablename__ = "curation_runs"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    finished_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
    # running | ok | partial | error
    status: Mapped[str] = mapped_column(String(16), default="running", index=True)
    departments_total: Mapped[int] = mapped_column(Integer, default=0)
    departments_covered: Mapped[int] = mapped_column(Integer, default=0)
    products_created: Mapped[int] = mapped_column(Integer, default=0)
    details: Mapped[dict] = mapped_column(JSON, default=dict)
