"""Blog tables: posts + generation runs (audit trail)."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _now() -> datetime:
    return datetime.now(timezone.utc)


class BlogPost(Base):
    __tablename__ = "blog_posts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slug: Mapped[str] = mapped_column(String(220), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(300))
    category: Mapped[str] = mapped_column(String(60), default="AI Growth")
    excerpt: Mapped[str] = mapped_column(Text, default="")
    meta_description: Mapped[str] = mapped_column(String(200), default="")
    # Body is a list of paragraph strings (inline HTML allowed), exactly
    # the shape the website article view has always rendered.
    body: Mapped[list] = mapped_column(JSON, default=list)
    image_url: Mapped[str] = mapped_column(String(1000), default="")
    image_alt: Mapped[str] = mapped_column(String(500), default="")
    word_count: Mapped[int] = mapped_column(Integer, default=0)
    read_minutes: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(20), default="published",
                                        index=True)
    # ai (backend generator) | manual (API) | seed (migrated from website)
    source: Mapped[str] = mapped_column(String(20), default="ai")
    provider: Mapped[str] = mapped_column(String(40), default="")
    published_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now)


class BlogRun(Base):
    """One generator attempt — published or skipped, always explained."""

    __tablename__ = "blog_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now)
    finished_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="running")
    topic: Mapped[str] = mapped_column(String(300), default="")
    post_slug: Mapped[str] = mapped_column(String(220), default="")
    detail: Mapped[str] = mapped_column(Text, default="")
    provider: Mapped[str] = mapped_column(String(40), default="")
