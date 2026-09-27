"""Discovery API — Virello's organic growth ecosystem.

Users opt in to topics; the matcher surfaces campaigns from genuinely
relevant creators. All engagement here is real by construction.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.models.growth import DiscoveryPlacement, Topic
from app.services.discovery import (
    get_feed, get_my_interests, get_placement_stats, record_interaction,
    request_placement, set_my_interests, seed_topics,
)

router = APIRouter()


@router.get("/topics")
async def topics(db: AsyncSession = Depends(get_db)) -> dict:
    await seed_topics(db)
    rows = (await db.execute(select(Topic).where(Topic.active.is_(True)))).scalars().all()
    return {"topics": [{"slug": t.slug, "name_en": t.name_en,
                         "name_ur": t.name_ur} for t in rows]}


@router.get("/interests")
async def my_interests(db: AsyncSession = Depends(get_db),
                       user: User = Depends(get_current_user)) -> dict:
    return {"topics": await get_my_interests(db, user.id)}


class InterestsIn(BaseModel):
    topics: list[str] = []


@router.put("/interests")
async def put_interests(body: InterestsIn, db: AsyncSession = Depends(get_db),
                        user: User = Depends(get_current_user)) -> dict:
    return {"topics": await set_my_interests(db, user.id, body.topics)}


@router.get("/feed")
async def feed(limit: int = 20, offset: int = 0,
               db: AsyncSession = Depends(get_db),
               user: User = Depends(get_current_user)) -> dict:
    items = await get_feed(db, user, limit=min(limit, 50), offset=offset)
    # Link-card support: every feed item carries its post type, derived from
    # the URL host with the same mapping the reader uses. Generic web links
    # get 'link' (backend detect_platform stores 'unknown' for these, so the
    # URL — not the stored platform string — is the source of truth).
    for it in items:
        it["post_type"] = _post_type_for_url(it.get("post_url") or "")
    # Sponsored slot (Phase 2 ad network): a SEPARATE labeled list injected
    # alongside the organic feed. Organic items are never relabeled, and
    # every sponsored unit carries is_sponsored=true + a "Sponsored" label.
    # Failure here must never break the organic feed.
    sponsored: list[dict] = []
    try:
        from app.services import ad_distribution as _dist
        sponsored = await _dist.serve_ads(db, user, limit=2)
    except Exception:
        sponsored = []
    return {"items": items, "sponsored": sponsored,
            "limit": limit, "offset": offset}


class InteractionIn(BaseModel):
    campaign_id: str
    kind: str  # view | save | visit | dismiss
    variant_id: str | None = None  # growth-engine variant actually displayed


@router.post("/interactions")
async def interact(body: InteractionIn, db: AsyncSession = Depends(get_db),
                   user: User = Depends(get_current_user)) -> dict:
    try:
        vid = uuid.UUID(body.variant_id) if body.variant_id else None
        return await record_interaction(db, user.id, uuid.UUID(body.campaign_id),
                                        body.kind, variant_id=vid)
    except ValueError as exc:
        raise HTTPException(400, str(exc))


class PlacementIn(BaseModel):
    campaign_id: str
    topics: list[str] = []


@router.post("/placements")
async def opt_in(body: PlacementIn, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    """Creator opts a campaign into the discovery pool."""
    try:
        p = await request_placement(db, user.id, uuid.UUID(body.campaign_id),
                                    body.topics)
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    return {"placement_id": str(p.id), "status": p.status,
            "topics": p.topics, "review_note": p.review_note}


@router.get("/placements/mine")
async def my_placements(db: AsyncSession = Depends(get_db),
                        user: User = Depends(get_current_user)) -> dict:
    from app.models.core import Campaign
    stmt = (select(DiscoveryPlacement, Campaign)
            .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
            .where(Campaign.user_id == user.id))
    rows = (await db.execute(stmt)).all()
    return {"placements": [
        {"placement_id": str(p.id), "campaign_id": str(c.id),
         "title": c.title, "status": p.status, "topics": p.topics,
         "review_note": p.review_note} for p, c in rows]}


@router.get("/placements/{campaign_id}/stats")
async def placement_stats(campaign_id: str, db: AsyncSession = Depends(get_db),
                          user: User = Depends(get_current_user)) -> dict:
    try:
        return await get_placement_stats(db, user.id, uuid.UUID(campaign_id))
    except ValueError as exc:
        raise HTTPException(400, str(exc))


# ---------------------------------------------------------------------------
# In-app reader: copyright-safe transformed preview of a post.
#
# Content is never shown verbatim at length: the reader returns a short
# excerpt (<=280 chars) plus an automated summary and key points, with the
# source attributed as plain domain text. No logos, no full-body copy.
# ---------------------------------------------------------------------------
import re
from typing import Literal
from urllib.parse import urlparse

from app.services.analysis.fetcher import fetch_post

try:  # reuse the product-wide honesty guardrail when available
    from app.routers.ai import honesty_check
except Exception:  # pragma: no cover - defensive fallback
    def honesty_check(text: str) -> bool:  # type: ignore[no-redef]
        return "guaranteed viral" not in text.lower()


_SENT_SPLIT = re.compile(r"(?<=[.!?])\s+")


def _platform_from_host(host: str) -> str:
    h = host.lower()
    if "youtube" in h or "youtu.be" in h:
        return "youtube"
    if "tiktok" in h:
        return "tiktok"
    if "instagram" in h:
        return "instagram"
    if h.endswith("x.com") or "twitter" in h:
        return "twitter"
    if "facebook" in h or h.startswith("fb."):
        return "facebook"
    return "link"


def _domain(host: str) -> str:
    h = host.lower()
    return h[4:] if h.startswith("www.") else h


def _sentences(text: str) -> list[str]:
    return [s.strip() for s in _SENT_SPLIT.split(text.strip()) if s.strip()]


def _excerpt(description: str, limit: int = 280) -> str:
    d = description.strip()
    if len(d) <= limit:
        return d
    cut = d[:limit].rsplit(" ", 1)[0]
    return (cut if cut else d[:limit]).rstrip() + "…"


_SUMMARY_PREFIX = {
    "en": "Automated AI summary",
    "ur": "خودکار AI خلاصہ",
    "ar": "ملخص تلقائي بالذكاء الاصطناعي",
}


def _ai_summary(title: str, domain: str, description: str,
                language: str) -> str:
    """Heuristic 2-3 sentence summary built ONLY from fetched metadata."""
    prefix = _SUMMARY_PREFIX.get(language, _SUMMARY_PREFIX["en"])
    sents = _sentences(description)
    parts = [f"{prefix}."]
    if title:
        parts.append(f"“{title[:120]}” — {domain}.")
    if sents:
        parts.append(sents[0][:200])
        if len(sents) > 1 and len(" ".join(parts)) < 320:
            parts.append(sents[1][:160])
    summary = " ".join(parts)
    if not honesty_check(summary):
        summary = f"{prefix}. {domain}."
    return summary


def _key_points(description: str, limit: int = 4) -> list[str]:
    points = []
    for s in _sentences(description):
        s = s if len(s) <= 140 else s[:137].rsplit(" ", 1)[0].rstrip() + "…"
        if s and s not in points:
            points.append(s)
        if len(points) >= limit:
            break
    return points


def _preview_word_count(*texts: str) -> int:
    """Word count of the TRANSFORMED preview only (never the original page)."""
    return sum(len(t.split()) for t in texts if t)


def _reading_time_min(word_count: int, wpm: int = 200) -> int:
    """Honest estimate of how long the in-app preview takes to read.

    Based on the transformed preview text, NOT the original page — the
    reader never fetches the full article body, so a full-article estimate
    would be fabricated.
    """
    return max(1, -(-word_count // wpm))


def _post_type_for_url(url: str) -> str:
    """Feed post type derived from the URL host, using the same mapping as
    the reader: generic web links -> 'link', social hosts -> platform name."""
    return _platform_from_host(urlparse(url or "").netloc or "")


class ReaderIn(BaseModel):
    url: str
    language: Literal["en", "ur", "ar"] = "en"


@router.post("/reader")
async def reader(body: ReaderIn,
                user: User = Depends(get_current_user)) -> dict:
    """Transformed in-app preview of a post. Never invents content."""
    raw = (body.url or "").strip()
    parsed = urlparse(raw)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise HTTPException(
            422, "That doesn't look like a valid public link. "
                 "Paste a full http(s) URL.")
    host = parsed.netloc
    domain = _domain(host)
    platform = _platform_from_host(host)
    try:
        res = await fetch_post(raw, platform)
    except Exception:
        raise HTTPException(
            422, "We couldn't reach that page right now. "
                 "Check the link and try again.")
    if res.level == "minimal" and not res.title and not res.description:
        raise HTTPException(
            422, "No readable preview is available for that link. "
                 "Nothing was fabricated — try the original page instead.")

    description = (res.description or "").strip()
    excerpt = _excerpt(description)  # empty when none; never invented
    summary = _ai_summary(res.title, domain, description, body.language)
    points = _key_points(description)
    # Link-card fields: word count + reading-time estimate of the
    # TRANSFORMED preview (not the original page). Backward compatible —
    # purely additive optional fields.
    word_count = _preview_word_count(excerpt, summary, *points)
    return {
        "title": res.title or domain,
        "source": domain,  # plain text only — never a logo
        "author": res.author or "",
        "excerpt": excerpt,
        "ai_summary": summary,
        "key_points": points,
        "topics": [],
        "thumbnail_url": res.thumbnail_url or "",
        "original_url": raw,
        "content_language": "",
        "word_count": word_count,
        "reading_time_min": _reading_time_min(word_count),
        "transformed": True,
    }
