"""AI Academy data models — Phase 5 of the Virello evolution.

Lessons with multi-section content and server-graded quizzes (answer
indices never leave the server until grading). Per-user progress tracked
honestly — real DB rows only, zeros when empty.

Follows the Base/GUID/_uuid patterns from app.models.ai_core.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.core import Base, GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class Lesson(Base):
    """One Academy lesson.

    content_json: {"sections": [{"heading": str, "body": str}, ...]}
    quiz_json: {"questions": [{"q": str, "options": [4 str],
                               "answer": int_index, "explanation": str}, ...]}
    """

    __tablename__ = "lessons"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(
        String(32), index=True, default="content"
    )  # content | growth | commerce | marketing
    level: Mapped[str] = mapped_column(
        String(16), default="beginner"
    )  # beginner | intermediate | advanced
    language: Mapped[str] = mapped_column(String(8), default="en")
    content_json: Mapped[dict] = mapped_column(JSON, default=dict)
    quiz_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0, index=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class LessonProgress(Base):
    """Per-user progress on a lesson. Quiz answers are graded server-side;
    only the score is stored — the user's answers are not kept."""

    __tablename__ = "lesson_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "lesson_id", name="uq_progress_user_lesson"),
    )

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), index=True
    )
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("lessons.id"), index=True
    )
    status: Mapped[str] = mapped_column(
        String(16), default="started"
    )  # started | completed
    quiz_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
