"""Community directory API: browse + AI-matched suggestions.

Read-only discovery. Virello never posts to these communities automatically.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.data.seed_communities import CATEGORIES
from app.models.community import Community
from app.models.core import SocialConnection, User

router = APIRouter(prefix="/communities", tags=["communities"])


class CommunityOut(BaseModel):
    id: str
    platform: str
    name: str
    url: str
    category: str
    description: str
    member_count: int
    match_reason: str | None = None


class CategoryOut(BaseModel):
    id: str
    name: str
    icon: str
    community_count: int = 0


def _to_out(c: Community, reason: str | None = None) -> CommunityOut:
    return CommunityOut(
        id=str(c.id),
        platform=c.platform,
        name=c.name,
        url=c.url,
        category=c.category,
        description=c.description,
        member_count=c.member_count,
        match_reason=reason,
    )


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)):
    counts = (
        (await db.execute(
            select(Community.category, func.count(Community.id)).group_by(Community.category)
        ))
        .all()
    )
    count_map = {row[0]: row[1] for row in counts}
    return [
        CategoryOut(
            id=c["id"],
            name=c["name"],
            icon=c["icon"],
            community_count=count_map.get(c["id"], 0),
        )
        for c in CATEGORIES
    ]


@router.get("", response_model=list[CommunityOut])
async def browse_communities(
    category: str | None = Query(default=None),
    platform: str | None = Query(default=None),
    q: str | None = Query(default=None),
    limit: int = Query(default=50, le=100),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    stmt = select(Community).order_by(Community.member_count.desc()).limit(limit)
    if category:
        stmt = stmt.where(Community.category == category)
    if platform:
        stmt = stmt.where(Community.platform == platform)
    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            (Community.name.ilike(like))
            | (Community.description.ilike(like))
            | (Community.topics.ilike(like))
        )
    rows = (await db.execute(stmt)).scalars().all()
    return [_to_out(c) for c in rows]


class SuggestIn(BaseModel):
    content: str
    topics: list[str] = []
    category: str | None = None
    limit: int = 10


@router.post("/suggest", response_model=list[CommunityOut])
async def suggest_communities(
    body: SuggestIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """AI-matched community suggestions for a post.

    Keyword-heuristic matching against community topics (same honest
    approach as /discovery/recommended). Returns match reasons.
    """
    stmt = select(Community)
    if body.category:
        stmt = stmt.where(Community.category == body.category)
    all_rows = (await db.execute(stmt)).scalars().all()

    haystack = (body.content + " " + " ".join(body.topics)).lower()
    scored: list[tuple[int, str, Community]] = []
    for c in all_rows:
        keywords = [k.strip().lower() for k in (c.topics or "").split(",") if k.strip()]
        hits = [k for k in keywords if k and k in haystack]
        if hits:
            scored.append((len(hits), ", ".join(hits[:3]), c))
    scored.sort(key=lambda t: (-t[0], -t[2].member_count))
    top = scored[: body.limit]
    if not top:
        # Fallback: biggest communities in the requested category (or overall)
        fallback = sorted(all_rows, key=lambda c: -c.member_count)[: body.limit]
        return [_to_out(c, "Popular in this category") for c in fallback]
    return [_to_out(c, f"Matches: {reason}") for _, reason, c in top]


@router.get("/connected-accounts")
async def connected_accounts(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Which social platforms the user has connected via OAuth."""
    rows = (
        (await db.execute(
            select(SocialConnection.platform).where(SocialConnection.user_id == user.id)
        ))
        .scalars()
        .all()
    )
    platforms = sorted(set(rows))
    return {"connected": platforms, "has_any": len(platforms) > 0}
