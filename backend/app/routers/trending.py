"""Trending Topics API: curated trending topics with AI content insights.

Public endpoints (no auth required) — the website's "Trending Now"
section fetches from here so new topics appear automatically.

Content contract:
- Summaries are original (never copied verbatim from Wikipedia/Google).
- Every topic carries an ai_insight: one line on how to create content
  about it.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.models.trending import TrendingTopic
from app.routers.admin import require_admin
from app.services.trending_orchestrator import run_trending_update

router = APIRouter(prefix="/trending", tags=["trending"])


class TrendingTopicOut(BaseModel):
    id: str
    title: str
    category: str
    summary: str
    ai_insight: str
    image_url: str
    source: str
    trend_score: int
    created_at: str

    model_config = {"from_attributes": True}


def _to_out(t: TrendingTopic) -> TrendingTopicOut:
    return TrendingTopicOut(
        id=str(t.id),
        title=t.title,
        category=t.category,
        summary=t.summary or "",
        ai_insight=t.ai_insight or "",
        image_url=t.image_url or "",
        source=t.source or "",
        trend_score=t.trend_score or 0,
        created_at=t.created_at.isoformat() if t.created_at else "",
    )


@router.get("/topics")
async def list_topics(
    limit: int = Query(default=10, ge=1, le=100),
    category: str | None = Query(default=None, max_length=64),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """List trending topics, newest/highest-scored first."""
    stmt = select(TrendingTopic).order_by(
        desc(TrendingTopic.trend_score), desc(TrendingTopic.created_at)
    )
    if category:
        stmt = stmt.where(TrendingTopic.category == category)
    stmt = stmt.limit(limit)
    res = await db.execute(stmt)
    topics = res.scalars().all()
    return {
        "total": len(topics),
        "topics": [_to_out(t) for t in topics],
    }


@router.get("/topics/{topic_id}")
async def get_topic(
    topic_id: str,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get a single trending topic by id."""
    try:
        uid = uuid.UUID(topic_id)
    except (ValueError, AttributeError):
        raise HTTPException(status_code=400, detail="Invalid topic id")
    res = await db.execute(
        select(TrendingTopic).where(TrendingTopic.id == uid)
    )
    topic = res.scalar_one_or_none()
    if topic is None:
        raise HTTPException(status_code=404, detail="Topic not found")
    return {"topic": _to_out(topic)}


@router.post("/refresh")
async def refresh_topics(
    _admin=Depends(require_admin),
) -> dict:
    """Trigger the trending robot (admin only).

    Discovers fresh trends, writes original content + images for new
    topics, and refreshes scores for existing ones.
    Returns {"added", "updated", "candidates"}.
    """
    result = await run_trending_update()
    return {"ok": True, **result}
