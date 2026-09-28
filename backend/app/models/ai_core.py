"""AI Core data model — conversation memory, cross-module context, intent logs.

Phase 0 of the Virello evolution: the central AI Core that will coordinate
all modules (Create, Discover, Grow, Shop, Academy, Entertainment).

Additive only. Follows the Base/GUID patterns from app.models.core.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.core import Base, GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class AIConversation(Base):
    """One Ask Virello conversation thread belonging to a user."""
    __tablename__ = "ai_conversations"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(255), default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class AIMessage(Base):
    """A single turn inside an AIConversation.

    role: user | assistant | system.
    intent/module/meta describe how the assistant turn was produced;
    meta may carry provider/dev labels and honesty flags — never fake data.
    """
    __tablename__ = "ai_messages"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    conversation_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ai_conversations.id"), index=True)
    role: Mapped[str] = mapped_column(String(16))  # user | assistant | system
    content: Mapped[str] = mapped_column(Text, default="")
    intent: Mapped[str | None] = mapped_column(String(64), nullable=True)
    module: Mapped[str | None] = mapped_column(String(64), nullable=True)
    meta: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)


class AIContext(Base):
    """Cross-module memory for one user — the AI Core's shared context.

    summary: running natural-language summary, appended to (never silently
    overwritten). entities/preferences: merged dicts (new keys win).
    """
    __tablename__ = "ai_contexts"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), unique=True, index=True)
    summary: Mapped[str] = mapped_column(Text, default="")
    entities: Mapped[dict] = mapped_column(JSON, default=dict)
    preferences: Mapped[dict] = mapped_column(JSON, default=dict)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class AIIntentLog(Base):
    """Audit trail of every classified Ask Virello input."""
    __tablename__ = "ai_intent_logs"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    conversation_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("ai_conversations.id"), nullable=True)
    raw_input: Mapped[str] = mapped_column(Text, default="")
    intent: Mapped[str] = mapped_column(String(64), index=True)
    confidence: Mapped[float] = mapped_column(Float, default=0.0)
    module: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)
