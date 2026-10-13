"""AI Image Generation jobs — DB-backed so polling works across uvicorn workers.

Mirrors the VideoJob pattern (app/models/video.py): the previous synchronous
POST /create/image-agnes held the request open for up to 120s against the
Agnes API. Slow generations timed out at the proxy/mobile layer. Now POST
returns a job_id immediately (202 Accepted) and a background task performs
the Agnes call; the app polls GET /create/image-jobs/{job_id} until
status is ready|failed.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


class ImageJob(Base):
    """One Agnes AI image generation job. Short-lived rows: the app polls
    GET /create/image-jobs/{job_id} until status is ready|failed. Rows older
    than an hour are pruned lazily on submit/poll."""

    __tablename__ = "image_jobs"

    # uuid4 hex (32 chars); String(36) leaves headroom.
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    prompt: Mapped[str] = mapped_column(Text(), nullable=False)
    style: Mapped[str] = mapped_column(String(20), default="realistic")
    seed: Mapped[int | None] = mapped_column(Integer(), nullable=True)
    status: Mapped[str] = mapped_column(
        String(16), default="pending", index=True)
    # pending | processing | ready | failed
    image_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    error: Mapped[str | None] = mapped_column(Text(), nullable=True)
    # Correlates mobile request -> backend logs -> Agnes call.
    request_id: Mapped[str] = mapped_column(String(36), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False)
