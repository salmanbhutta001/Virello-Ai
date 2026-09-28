"""Community directory: curated public groups/communities by niche.

Legitimate discovery tool — helps users find WHERE their audience hangs out.
Virello never auto-posts to these communities; users share manually via
one-tap share sheets after reviewing. No spam, no bypass.
"""
from __future__ import annotations

import datetime
import uuid

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.core import Base, GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class Community(Base):
    """A curated public community (subreddit, FB group, board, forum...)."""

    __tablename__ = "communities"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(), primary_key=True, default=_uuid
    )
    platform: Mapped[str] = mapped_column(
        String(32), index=True
    )  # reddit | facebook | pinterest | forum | discord ...
    name: Mapped[str] = mapped_column(String(255), index=True)
    url: Mapped[str] = mapped_column(String(1024))
    category: Mapped[str] = mapped_column(
        String(64), index=True
    )  # fitness | business | tech | food ...
    topics: Mapped[str] = mapped_column(
        Text, default=""
    )  # comma-separated keywords for AI matching
    description: Mapped[str] = mapped_column(Text, default="")
    member_count: Mapped[int] = mapped_column(default=0)
    language: Mapped[str] = mapped_column(String(16), default="en")
    is_verified: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
