"""Virello Spotlight — transparent creator featuring.

Users OPT IN explicitly: they submit their content + link + handle and give
clear consent for Virello to feature it on Virello's official social accounts
WITH credit ("Featured Creator: @handle"). Nothing is ever posted secretly —
the user knows, the audience sees the disclosure. This is the legitimate
alternative to secret cross-posting: editorial featuring, not manufactured
traffic.

V1: submission + admin review queue. Posting itself is manual (Hafiz posts
from Virello's accounts with the disclosure) until social posting APIs are
connected.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class SpotlightSubmission(Base):
    """A user's opt-in request to be featured on Virello's accounts."""

    __tablename__ = "spotlight_submissions"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True, default=_uuid)
    content: Mapped[str] = mapped_column(Text)
    link: Mapped[str] = mapped_column(String(300), default="")
    creator_handle: Mapped[str] = mapped_column(String(80), default="")
    creator_email: Mapped[str] = mapped_column(String(255), default="")
    # Explicit opt-in: the user agreed Virello may feature this WITH credit.
    consent: Mapped[bool] = mapped_column(default=False)
    consent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
    # pending -> approved/rejected -> posted (after Hafiz posts it manually)
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    admin_note: Mapped[str] = mapped_column(String(500), default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
