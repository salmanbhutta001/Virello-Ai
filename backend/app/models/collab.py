"""Creator Collab Match — free organic growth strategy #4.

Creators opt in to a public matchmaking pool; link owners (other Virello
users) find creators by topic overlap and send collaboration requests.
A creator who accepts may genuinely share the owner's post with their
audience — the *only* distribution mechanism here is a real human choosing
to share.

Honesty rules, enforced in code:
- audience_size is SELF-DECLARED. It is never labeled "verified",
  "estimated reach", or anything implying independent measurement.
- match scores are labeled "topic_fit" = |overlap| / |requested topics|;
  a simple, explainable number — not "guaranteed" anything.
- request status changes ONLY through the involved parties' own actions:
  the creator accepts/declines; the link owner marks "shared" after the
  creator genuinely shared. No fabricated share tracking.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    JSON, Boolean, DateTime, ForeignKey, Integer, String, Text, func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _hex() -> str:
    return uuid.uuid4().hex


class CreatorProfile(Base):
    """A user's public opt-in creator profile for collab matching.

    One profile per user (unique user_id). is_opted_in=False removes the
    profile from match results without deleting it.
    """

    __tablename__ = "creators"
    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_hex)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(120))
    topics: Mapped[list] = mapped_column(JSON, default=list)  # topic slugs
    platforms: Mapped[list] = mapped_column(
        JSON, default=list)  # e.g. ["instagram", "tiktok"]
    # SELF-DECLARED by the creator. Never shown as verified.
    audience_size: Mapped[int | None] = mapped_column(
        Integer, nullable=True, default=None)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True, default=None)
    is_opted_in: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="1")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class CollabRequest(Base):
    """Link owner -> creator collaboration request.

    Status lifecycle (transitions only via the actors' own API calls):
        pending -> accepted | declined   (creator decides)
        accepted -> shared                (owner confirms a genuine share)
    """

    PENDING = "pending"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    SHARED = "shared"
    VALID_STATUSES = (PENDING, ACCEPTED, DECLINED, SHARED)

    __tablename__ = "collab_requests"
    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_hex)
    link_owner_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    creator_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("creators.id"), index=True)
    post_url: Mapped[str] = mapped_column(String(1024))
    message: Mapped[str | None] = mapped_column(
        String(1000), nullable=True, default=None)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default=PENDING, server_default=PENDING)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    decided_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, default=None)
