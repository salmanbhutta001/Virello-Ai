"""AI Video Generation jobs — DB-backed so polling works across uvicorn workers.

The previous in-memory job store broke as soon as the backend ran with
--workers 2: a poll landing on the other worker got 404 "Unknown video job".
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class VideoJob(Base):
    """One Agnes AI video generation job. Short-lived rows: the app polls
    GET /video/jobs/{job_id} until status is ready|failed. Old rows are
    pruned on each new submission."""

    __tablename__ = "video_jobs"

    job_id: Mapped[str] = mapped_column(String(12), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    agnes_id: Mapped[str | None] = mapped_column(Text(), nullable=True)
    status: Mapped[str] = mapped_column(
        String(16), default="submitted", index=True)
    # submitted | processing | ready | failed
    video_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    error: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False)
