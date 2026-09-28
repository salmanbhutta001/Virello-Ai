"""Ask Virello — AI Core API.

POST /ask takes natural language, classifies intent, dispatches to the
mapped Virello module with shared per-user context, and returns a
structured response. Additive only (Phase 0).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.ai_core import AIConversation, AIMessage
from app.models.core import User
from app.services.ai_core import router as intent_router
from app.services.ai_core.context import (
    get_context,
    get_recent_messages,
    reset_context,
)
from app.services.ai_core.coordinator import handle_ask

router = APIRouter(prefix="/ai-core", tags=["ai-core"])


class AskIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=4000)
    conversation_id: str | None = None
    language: str | None = Field(default=None, pattern="^(en|ur|ar)$")


class AskOut(BaseModel):
    intent: str
    confidence: float
    intents: list[dict] = []
    module: str
    module_status: str
    method: str
    reply: str
    reply_language: str
    dev: bool
    provider: str | None = None
    actions: list[dict] = []
    plan: list[dict] = []
    conversation_id: str
    context_updated: bool


class ConversationOut(BaseModel):
    id: str
    title: str
    created_at: str
    updated_at: str


class MessageOut(BaseModel):
    id: str
    role: str
    content: str
    intent: str | None = None
    module: str | None = None
    meta: dict = {}
    created_at: str


class ContextOut(BaseModel):
    summary: str
    entities: dict
    preferences: dict
    updated_at: str


def _parse_uuid(value: str | None) -> uuid.UUID | None:
    if not value:
        return None
    try:
        return uuid.UUID(value)
    except (ValueError, AttributeError):
        return None


@router.post("/ask", response_model=AskOut)
async def ask(
    payload: AskIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Natural-language → intent → module → structured response."""
    result = await handle_ask(
        db,
        user,
        payload.text,
        conversation_id=_parse_uuid(payload.conversation_id),
        language=payload.language,
    )
    return result


@router.get("/conversations", response_model=list[ConversationOut])
async def list_conversations(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    limit: int = Query(default=20, ge=1, le=100),
):
    res = await db.execute(
        select(AIConversation)
        .where(AIConversation.user_id == user.id)
        .order_by(desc(AIConversation.updated_at))
        .limit(limit)
    )
    return [
        ConversationOut(
            id=str(c.id), title=c.title or "",
            created_at=c.created_at.isoformat() if c.created_at else "",
            updated_at=c.updated_at.isoformat() if c.updated_at else "",
        )
        for c in res.scalars().all()
    ]


@router.get("/conversations/{conversation_id}", response_model=list[MessageOut])
async def conversation_messages(
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    limit: int = Query(default=50, ge=1, le=200),
):
    cid = _parse_uuid(conversation_id)
    if cid is None:
        raise HTTPException(404, "Conversation not found")
    # Ownership check — never leak other users' threads. Read-only: a miss
    # is a 404, never an implicit create.
    res = await db.execute(
        select(AIConversation).where(
            AIConversation.id == cid,
            AIConversation.user_id == user.id,
        )
    )
    if res.scalar_one_or_none() is None:
        raise HTTPException(404, "Conversation not found")
    messages = await get_recent_messages(db, cid, limit=limit)
    return [
        MessageOut(
            id=str(m.id), role=m.role, content=m.content,
            intent=m.intent, module=m.module, meta=m.meta or {},
            created_at=m.created_at.isoformat() if m.created_at else "",
        )
        for m in messages
    ]


@router.get("/context", response_model=ContextOut)
async def read_context(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ctx = await get_context(db, user.id)
    return ContextOut(
        summary=ctx.summary or "",
        entities=ctx.entities or {},
        preferences=ctx.preferences or {},
        updated_at=ctx.updated_at.isoformat() if ctx.updated_at else "",
    )


@router.delete("/context")
async def delete_context(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await reset_context(db, user.id)
    return {"ok": True, "reset": True}


@router.get("/intents")
async def list_intents():
    """Public: the intent vocabulary + which module serves each."""
    return {
        "method": intent_router.METHOD,
        "intents": [
            {"intent": name, **intent_router.module_for(name)}
            for name in intent_router.INTENTS
        ],
    }
