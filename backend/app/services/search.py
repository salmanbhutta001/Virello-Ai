"""Full-text search for Virello — posts, users.

Honest search over real data only. No fake results, no invented matches.
Relevance-ranked: exact title > prefix > contains > topic/platform match.
Typo-tolerant: diacritics stripped, multi-word queries match any word.
"""
from __future__ import annotations

import re
import unicodedata

from sqlalchemy import String, and_, case, cast, desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.core import Campaign, CampaignStatus, User
from app.models.growth import DiscoveryPlacement


def normalize_query(q: str) -> str:
    """Lowercase, strip diacritics/accents, collapse whitespace."""
    q = unicodedata.normalize("NFKD", q or "")
    q = "".join(c for c in q if not unicodedata.combining(c))
    q = q.lower().strip()
    q = re.sub(r"\s+", " ", q)
    return q


def query_words(q: str) -> list[str]:
    """Split into significant words (drop tiny stopwords)."""
    stop = {"the", "a", "an", "and", "or", "of", "in", "on", "to", "for",
            "ka", "ki", "ke", "aur", "mein", "me", "se", "ko"}
    return [w for w in normalize_query(q).split(" ") if w and w not in stop]


async def search_posts(db: AsyncSession, q: str,
                       limit: int = 20) -> list[dict]:
    """Search approved discovery posts by title, URL, platform, topics.

    Returns feed-compatible item dicts, relevance-ranked.
    """
    words = query_words(q)
    if not words:
        return []

    # Build OR conditions: each word matches title/url/platform/topics.
    # Topics is a JSON list — cast to text for LIKE matching.
    conditions = []
    for w in words:
        like = f"%{w}%"
        conditions.append(or_(
            func.lower(Campaign.title).like(like),
            func.lower(Campaign.post_url).like(like),
            func.lower(Campaign.platform).like(like),
            func.lower(cast(DiscoveryPlacement.topics, String)).like(like),
        ))

    # Relevance score via CASE: exact title > prefix > contains > other.
    # Use the first (most significant) word for tiered ranking.
    w0 = words[0]
    w0_like = f"%{w0}%"
    score = case(
        (func.lower(Campaign.title) == w0, 100),
        (func.lower(Campaign.title).like(f"{w0}%"), 80),
        (func.lower(Campaign.title).like(w0_like), 60),
        (func.lower(cast(DiscoveryPlacement.topics, String)).like(w0_like), 40),
        (or_(func.lower(Campaign.post_url).like(w0_like),
             func.lower(Campaign.platform).like(w0_like)), 20),
        else_=10,
    ).label("relevance")

    stmt = (
        select(DiscoveryPlacement, Campaign, score)
        .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
        .where(
            DiscoveryPlacement.status == "approved",
            Campaign.status == CampaignStatus.live,
            or_(*conditions),
        )
        .order_by(desc("relevance"), desc(Campaign.created_at))
        .limit(limit)
    )
    rows = (await db.execute(stmt)).all()

    items = []
    for placement, campaign, relevance in rows:
        items.append({
            "campaign_id": str(campaign.id),
            "placement_id": str(placement.id),
            "title": campaign.title or "",
            "platform": campaign.platform or "",
            "goal": campaign.goal.value if campaign.goal else "",
            "post_url": campaign.post_url or "",
            "thumbnail_url": "",
            "match_score": float(relevance or 0),
            "match_reasons": [f"Matches '{q.strip()}'"],
            "post_type": "",
            "reward_cents": placement.reward_cents or 0,
            "reward_display": "",
            "tagged_products": [],
            "content_language": "",
            "content_languages": [],
            "language_uncertain": False,
        })
    return items


async def search_users(db: AsyncSession, q: str,
                       limit: int = 20) -> list[dict]:
    """Search users by display name. Excludes suspended accounts."""
    words = query_words(q)
    if not words:
        return []

    conditions = []
    for w in words:
        like = f"%{w}%"
        conditions.append(func.lower(User.name).like(like))

    w0 = words[0]
    score = case(
        (func.lower(User.name) == w0, 100),
        (func.lower(User.name).like(f"{w0}%"), 80),
        else_=60,
    ).label("relevance")

    stmt = (
        select(User, score)
        .where(
            User.suspended.is_(False),
            User.name.isnot(None),
            or_(*conditions),
        )
        .order_by(desc("relevance"), desc(User.created_at))
        .limit(limit)
    )
    rows = (await db.execute(stmt)).all()

    users = []
    for user, relevance in rows:
        name = user.name or ""
        users.append({
            "id": str(user.id),
            "name": name,
            "handle": (user.email or "").split("@")[0],
            "initial": name[0].upper() if name else "?",
            "relevance": float(relevance or 0),
        })
    return users
