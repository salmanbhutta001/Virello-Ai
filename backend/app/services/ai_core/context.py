"""Per-user cross-module context store for the AI Core.

The AIContext row is the shared memory every module reads/writes:
summaries are appended (never silently overwritten), entities/preferences
are merged with new keys winning.
"""
from __future__ import annotations

import uuid

from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ai_core import AIContext, AIConversation, AIMessage

_MAX_SUMMARY_CHARS = 4000


async def get_context(db: AsyncSession, user_id: uuid.UUID) -> AIContext:
    """Return the user's AIContext, creating an empty one if missing."""
    res = await db.execute(select(AIContext).where(AIContext.user_id == user_id))
    ctx = res.scalar_one_or_none()
    if ctx is None:
        ctx = AIContext(user_id=user_id, summary="", entities={}, preferences={})
        db.add(ctx)
        await db.commit()
        await db.refresh(ctx)
    return ctx


async def update_context(
    db: AsyncSession,
    user_id: uuid.UUID,
    summary_addenda: str | None = None,
    entities: dict | None = None,
    preferences: dict | None = None,
) -> AIContext:
    """Merge new information into the user's context (never overwrite)."""
    ctx = await get_context(db, user_id)
    if summary_addenda:
        addenda = summary_addenda.strip()
        if addenda:
            combined = f"{ctx.summary}\n- {addenda}" if ctx.summary else f"- {addenda}"
            # Keep the tail so memory stays bounded; newest information wins.
            ctx.summary = combined[-_MAX_SUMMARY_CHARS:]
    if entities:
        merged = dict(ctx.entities or {})
        merged.update({k: v for k, v in entities.items() if v is not None})
        ctx.entities = merged
    if preferences:
        merged = dict(ctx.preferences or {})
        merged.update({k: v for k, v in preferences.items() if v is not None})
        ctx.preferences = merged
    await db.commit()
    await db.refresh(ctx)
    return ctx


async def reset_context(db: AsyncSession, user_id: uuid.UUID) -> None:
    """Delete the user's AIContext row (fresh start)."""
    res = await db.execute(select(AIContext).where(AIContext.user_id == user_id))
    ctx = res.scalar_one_or_none()
    if ctx is not None:
        await db.delete(ctx)
        await db.commit()


async def get_or_create_conversation(
    db: AsyncSession,
    user_id: uuid.UUID,
    conversation_id: uuid.UUID | None = None,
    title: str = "",
) -> AIConversation:
    """Return the user's conversation, or create a new one.

    A supplied conversation_id belonging to another user is ignored and a
    new conversation is created instead (never leak other users' threads).
    """
    if conversation_id is not None:
        res = await db.execute(
            select(AIConversation).where(
                AIConversation.id == conversation_id,
                AIConversation.user_id == user_id,
            )
        )
        convo = res.scalar_one_or_none()
        if convo is not None:
            return convo
    convo = AIConversation(user_id=user_id, title=title[:120])
    db.add(convo)
    await db.commit()
    await db.refresh(convo)
    return convo


async def get_recent_messages(
    db: AsyncSession, conversation_id: uuid.UUID, limit: int = 20
) -> list[AIMessage]:
    """Most recent messages, returned oldest-first for prompt building."""
    res = await db.execute(
        select(AIMessage)
        .where(AIMessage.conversation_id == conversation_id)
        .order_by(desc(AIMessage.created_at))
        .limit(limit)
    )
    return list(reversed(res.scalars().all()))


async def add_message(
    db: AsyncSession,
    conversation_id: uuid.UUID,
    role: str,
    content: str,
    intent: str | None = None,
    module: str | None = None,
    meta: dict | None = None,
) -> AIMessage:
    """Persist one conversation turn."""
    msg = AIMessage(
        conversation_id=conversation_id,
        role=role,
        content=content,
        intent=intent,
        module=module,
        meta=meta or {},
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return msg
