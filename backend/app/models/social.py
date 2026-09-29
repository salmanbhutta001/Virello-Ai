"""Social graph basics: creators the user follows inside Virello.

The Following tab is real: a follow is a deliberate, user-initiated save of
a creator handle (e.g. discovered through the audience-insights flow). No
follow is ever created without the user tapping follow, and no follow data
is scraped from anywhere.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _hex() -> str:
    return uuid.uuid4().hex


class Follow(Base):
    """One user → creator follow. Unique per (user, handle)."""

    __tablename__ = "follows"
    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_hex)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    creator_handle: Mapped[str] = mapped_column(String(255))
    # normalized: leading '@' stripped, lowercased
    creator_name: Mapped[str | None] = mapped_column(
        String(255), nullable=True, default=None)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "creator_handle",
                         name="uq_follow_user_handle"),
    )


class PostComment(Base):
    """A genuine user comment on a discovery post.

    Keyed by the post's canonical URL because discovery items are external
    posts that have no row in our database. Only ever created by the
    authenticated user's explicit action — never seeded, never fabricated.
    The author's display name is snapshotted at write time from their
    profile (name or email prefix); emails are never exposed.
    """

    __tablename__ = "post_comments"
    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_hex)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    post_url: Mapped[str] = mapped_column(String(2048), index=True)
    text: Mapped[str] = mapped_column(String(2000))
    author_name: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
