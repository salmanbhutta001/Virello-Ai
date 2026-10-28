"""Discovery API — Virello's organic growth ecosystem.

Users opt in to topics; the matcher surfaces campaigns from genuinely
relevant creators. All engagement here is real by construction.
"""
from __future__ import annotations

import asyncio
import os
import re
import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.commerce import PostProduct, Product
from app.models.core import User
from app.models.growth import DiscoveryPlacement, Topic
from app.services.affiliate.amazon import AmazonAffiliateProvider
from app.services.discovery import (
    get_feed, get_my_interests, get_placement_stats, record_interaction,
    request_placement, set_my_interests, seed_topics,
)
from app.services.discovery.service import tagged_products_for_placements
from app.services.discovery.trend_images import (  # noqa: F401 — registers TrendImageCache model
    resolve_trend_thumbnails,
)
from app.services.discovery.trend_cache import (
    CACHE_LIMIT,
    build_response,
    cache_is_fresh,
    fetch_trends_live,
    read_trend_cache,
    write_trend_cache,
)

router = APIRouter()


def _curator_token_ok(token: str | None) -> bool:
    """Service-to-service check — same as /curate (VIRELLO_CURATOR_TOKEN)."""
    expected = os.environ.get("VIRELLO_CURATOR_TOKEN", "")
    return bool(expected) and bool(token) and secrets.compare_digest(token, expected)


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


@router.get("/search")
async def search_posts(
    q: str = Query(default="", max_length=120),
    limit: int = Query(default=20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """Full-text search over approved discovery posts.

    Matches title, post URL, platform, and topics — case-insensitive,
    partial, typo-tolerant, relevance-ranked. Only real matches; empty
    query returns empty (trending suggestions come from /trending).
    """
    from app.services.search import normalize_query, search_posts as _search
    query = normalize_query(q)
    if not query:
        return {"items": [], "query": "", "total": 0}
    items = await _search(db, query, limit=limit)
    # Link-card support: same post_type derivation as /feed.
    for it in items:
        it["post_type"] = _post_type_for_url(it.get("post_url") or "")
    return {"items": items, "query": query, "total": len(items)}


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
    kind: str  # view | save | visit | dismiss | like
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


@router.get("/interactions/mine")
async def my_interactions(kind: str | None = None,
                          limit: int = 50,
                          db: AsyncSession = Depends(get_db),
                          user: User = Depends(get_current_user)) -> dict:
    """The caller's own genuine interactions (e.g. kind=like), newest first.

    Joined with campaign titles so the app can show what was liked.
    Only the caller's own rows — never anyone else's.
    """
    from app.models.core import Campaign
    from app.models.growth import DiscoveryInteraction
    limit = max(1, min(limit, 100))
    stmt = (select(DiscoveryInteraction, Campaign.title)
            .join(Campaign, Campaign.id == DiscoveryInteraction.campaign_id)
            .where(DiscoveryInteraction.user_id == user.id)
            .order_by(DiscoveryInteraction.created_at.desc())
            .limit(limit))
    if kind:
        stmt = stmt.where(DiscoveryInteraction.kind == kind)
    rows = (await db.execute(stmt)).all()
    return {"interactions": [
        {"kind": i.kind,
         "campaign_id": str(i.campaign_id),
         "campaign_title": title,
         "created_at": i.created_at.isoformat() if i.created_at else None}
        for i, title in rows]}


class PlacementIn(BaseModel):
    campaign_id: str
    topics: list[str] = []
    # Shoppable post: Amazon ASINs to tag on the post (max 5). Each must
    # match a live catalog product's server-built affiliate URL, else 400.
    asins: list[str] = []
    # Create & Earn: "virello" when the post was made with Virello's AI
    # tools -> +5 creator_bonus points on top of the normal post points.
    created_with: str | None = None


_ASIN_RE = re.compile(r"^[A-Z0-9]{10}$")


@router.post("/placements", status_code=201)
async def opt_in(body: PlacementIn, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    """Creator opts a campaign into the discovery pool."""
    from app.services import rewards as rewards_svc

    raw_asins = [(a or "").strip().upper() for a in (body.asins or [])]
    if len(raw_asins) > 5:
        raise HTTPException(400, "At most 5 tagged products per post")
    for asin in raw_asins:
        if not _ASIN_RE.match(asin):
            raise HTTPException(400, f"Invalid ASIN: {asin}")

    try:
        p = await request_placement(db, user.id, uuid.UUID(body.campaign_id),
                                    body.topics)
    except ValueError as exc:
        raise HTTPException(400, str(exc))

    # Shoppable tags: every ASIN must resolve to an active catalog product
    # via the server-built affiliate URL (the client never supplies a tag).
    if raw_asins:
        provider = AmazonAffiliateProvider()
        for asin in raw_asins:
            url = provider.build_affiliate_url(asin)
            prod = (await db.execute(select(Product).where(
                Product.affiliate_url == url,
                Product.is_active.is_(True)))).scalar_one_or_none()
            if prod is None:
                raise HTTPException(
                    400, f"ASIN {asin} is not an active catalog product")
        existing = set((await db.execute(select(PostProduct.asin).where(
            PostProduct.post_id == p.id))).scalars().all())
        for asin in raw_asins:
            if asin not in existing:
                db.add(PostProduct(post_id=p.id, asin=asin))
                existing.add(asin)
        await db.commit()

    points_earned = 0
    try:
        if raw_asins:
            points_earned = await rewards_svc.award_post_with_products(
                db, user.id, uuid.UUID(body.campaign_id))
        else:
            points_earned = await rewards_svc.award_post_created(
                db, user.id, uuid.UUID(body.campaign_id))
    except Exception:
        log.exception("rewards: post_created hook failed")

    # Create & Earn: content made with Virello's AI tools earns a +5 bonus
    # on top of the normal post points. Idempotent per placement.
    created_with = (body.created_with or "").strip().lower() or None
    if created_with:
        p.created_with = created_with
        await db.commit()
    creator_bonus = 0
    if created_with == "virello":
        try:
            creator_bonus = await rewards_svc.award_creator_bonus(
                db, user.id, p.id)
        except Exception:
            log.exception("rewards: creator_bonus hook failed")
    points_earned += creator_bonus
    return {"placement_id": str(p.id), "status": p.status,
            "topics": p.topics, "review_note": p.review_note,
            "asins": raw_asins, "created_with": p.created_with,
            "points_earned": points_earned,
            "creator_bonus": creator_bonus}


@router.get("/placements/mine")
async def my_placements(db: AsyncSession = Depends(get_db),
                        user: User = Depends(get_current_user)) -> dict:
    from app.models.core import Campaign
    stmt = (select(DiscoveryPlacement, Campaign)
            .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
            .where(Campaign.user_id == user.id))
    rows = (await db.execute(stmt)).all()
    tagged = await tagged_products_for_placements(
        db, [p.id for p, _ in rows])
    return {"placements": [
        {"placement_id": str(p.id), "campaign_id": str(c.id),
         "title": c.title, "status": p.status, "topics": p.topics,
         "review_note": p.review_note,
         "tagged_products": tagged.get(p.id, [])} for p, c in rows]}


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


@router.get("/trending")
async def trending_now(
    geo: str = "US",
    limit: int = 10,
    lang: str = "en",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Real trending topics from free public sources — cache-first.

    Aggregates (no API keys needed, works from any server):
    - Wikimedia Top Articles: most-viewed Wikipedia articles (real pageviews)
      Supports language editions via `lang` (en, ur, ar, es, fr, de, etc.)
    - Google News RSS: current top headlines (real news)

    Served from a DB snapshot (``discovery_trends_cache``, TTL 1h) while
    fresh, so the app's Trending screen answers in <1s instead of waiting
    on a live upstream fetch that blew Vercel's 10s function limit and
    showed the app an empty screen. On expiry the snapshot is refetched
    (per-article summary calls run in parallel) and stored. A stale
    snapshot is served rather than an empty list when the live fetch
    fails. Returns honestly-labeled trend data — public attention
    signals, not Virello posts. Never fabricated.
    """
    # Validate language code (2-3 letter codes only) and clamp the page.
    lang = (lang or "en").lower().strip()[:3]
    if not lang.isalpha():
        lang = "en"
    geo = (geo or "US").upper().strip() or "US"
    limit = max(1, min(int(limit), CACHE_LIMIT))

    # 1. Fresh snapshot? Serve it immediately — no upstream calls.
    # A cache read failure degrades to a live fetch, never a 500.
    try:
        cached = await read_trend_cache(db, lang, geo)
    except Exception:
        cached = None
    if cached is not None:
        payload, fetched_at = cached
        cached_trends = payload.get("trends") or []
        if cached_trends and cache_is_fresh(fetched_at):
            out = build_response(
                cached_trends[:limit], payload.get("sources", []), lang
            )
            out["cached"] = True
            out["cached_at"] = fetched_at.isoformat() if fetched_at else None
            return out

    # 2. Expired/missing snapshot: refetch live (parallelized) and store.
    # Hard 7s budget: Vercel Hobby kills the function at 10s, so a slow
    # upstream must degrade to the stale snapshot (step 3), never to a
    # killed invocation and an empty screen in the app.
    try:
        trends, sources_used = await asyncio.wait_for(
            fetch_trends_live(db, geo=geo, limit=CACHE_LIMIT, lang=lang),
            timeout=7.0,
        )
    except (asyncio.TimeoutError, Exception):
        trends, sources_used = [], []
    if trends:
        payload = build_response(trends, sources_used, lang)
        await write_trend_cache(db, lang, geo, payload)
        out = build_response(trends[:limit], sources_used, lang)
        out["cached"] = False
        out["cached_at"] = None
        return out

    # 3. Live fetch failed: serve a stale snapshot rather than nothing.
    if cached is not None:
        payload, fetched_at = cached
        cached_trends = payload.get("trends") or []
        if cached_trends:
            out = build_response(
                cached_trends[:limit], payload.get("sources", []), lang
            )
            out["cached"] = True
            out["stale"] = True
            out["cached_at"] = fetched_at.isoformat() if fetched_at else None
            return out

    # 4. No snapshot at all and no live data: honest empty, as before.
    out = build_response([], [], lang)
    out["cached"] = False
    out["cached_at"] = None
    return out


@router.post("/trending/refresh")
async def refresh_trending(
    request: Request,
    geo: str = "US",
    lang: str = "en",
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Warm the trending snapshot now (curator token).

    Runs the live trend fetch and stores the snapshot, so the app's
    Trending screen serves it instantly. Called by the curation cron
    (every 3h) with the X-Curator-Token header — the same token as
    /curate. Admins can use POST /api/v1/trending/refresh (the robot)
    for the full curated-topics pipeline instead.
    """
    if not _curator_token_ok(request.headers.get("x-curator-token")):
        raise HTTPException(401, "Curator token required")
    lang = (lang or "en").lower().strip()[:3]
    if not lang.isalpha():
        lang = "en"
    geo = (geo or "US").upper().strip() or "US"
    try:
        trends, sources_used = await asyncio.wait_for(
            fetch_trends_live(db, geo=geo, limit=CACHE_LIMIT, lang=lang),
            timeout=7.0,
        )
    except (asyncio.TimeoutError, Exception):
        trends, sources_used = [], []
    ok = False
    write_error = ""
    if trends:
        payload = build_response(trends, sources_used, lang)
        ok, write_error = await write_trend_cache(db, lang, geo, payload)
    return {
        "ok": ok,
        "count": len(trends),
        "sources": sources_used,
        "language": lang,
        "geo": geo,
        # First 3 titles so the curation cron can log what was cached
        # (curator-token only — no user data).
        "sample": [t.get("query", "") for t in trends[:3]],
        # "" on success; the DB error when the snapshot could not be
        # stored (curator-only — lets the cron diagnose a failed warm).
        "write_error": write_error,
    }


# ---------------------------------------------------------------------------
# AI Recommended: interest-matched trends.
#
# Matches real trending topics against the user's selected interests using
# keyword matching. Honest heuristic — labeled as such, never fabricated.
# ---------------------------------------------------------------------------
_INTEREST_KEYWORDS: dict[str, list[str]] = {
    "travel": ["travel", "tourism", "dubai", "pakistan", "flight", "hotel",
               "destination", "trip", "vacation", "airline"],
    "fitness": ["fitness", "workout", "gym", "exercise", "yoga", "weight",
                "muscle", "training", "sport", "athlete"],
    "education": ["education", "school", "university", "learn", "study",
                  "student", "college", "course", "exam", "degree"],
    "music": ["music", "song", "singer", "album", "concert", "band",
              "k-pop", "coke studio", "musician", "spotify"],
    "technology": ["technology", "ai", "artificial intelligence", "smartphone",
                   "chatgpt", "tech", "software", "computer", "robot"],
    "gaming": ["game", "gaming", "minecraft", "pubg", "video game",
               "esports", "playstation", "xbox"],
    "finance": ["finance", "stock", "crypto", "bitcoin", "money", "bank",
                "investment", "market", "economy"],
    "food": ["food", "recipe", "pizza", "biryani", "cooking", "restaurant",
             "chef", "cuisine"],
    "beauty": ["beauty", "cosmetic", "skincare", "makeup", "skin"],
    "fashion": ["fashion", "style", "sneaker", "streetwear", "clothes"],
    "sports": ["cricket", "football", "sport", "olympic", "match", "team",
               "player", "championship", "league"],
    "health": ["health", "mental health", "nutrition", "disease", "doctor",
               "medical", "wellness"],
    "news": ["news", "politics", "election", "government", "president"],
    "business": ["business", "startup", "ecommerce", "company", "entrepreneur"],
    "entertainment": ["movie", "film", "actor", "actress", "celebrity",
                      "hollywood", "bollywood", "show", "series"],
}


@router.get("/recommended")
async def recommended_for_you(
    limit: int = 5,
    lang: str = "en",
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """AI-matched trends based on the user's selected interests.

    Fetches real trends, then scores each against the user's interests
    using keyword matching. Returns the best matches with match reasons.
    Honest heuristic — the matching is simple keyword scoring, labeled
    as such. Trends are real, never fabricated.
    """
    # Get user's interests
    interests = await get_my_interests(db, user.id)

    # Get real trends (reuse the trending logic)
    # We call the underlying trend fetch directly for efficiency
    import httpx
    from datetime import date, timedelta

    lang = (lang or "en").lower().strip()[:3]
    if not lang.isalpha():
        lang = "en"

    trends: list[dict] = []
    try:
        yesterday = date.today() - timedelta(days=1)
        wiki_url = (
            "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/"
            f"{lang}.wikipedia/all-access/"
            f"{yesterday.year}/{yesterday.month:02d}/{yesterday.day:02d}"
        )
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                wiki_url,
                headers={"User-Agent": "Virello/1.0 (recommended)"},
            )
            if resp.status_code == 200:
                data = resp.json()
                articles = data.get("items", [{}])[0].get("articles", [])
                for art in articles[:50]:  # check top 50 for matches
                    title = art.get("article", "").replace("_", " ").strip()
                    if not title or ":" in title:
                        continue
                    if title.startswith(".") or len(title) < 3:
                        continue
                    if title.lower().startswith("main page"):
                        continue
                    views = art.get("views", 0)

                    # Score against user interests
                    title_lower = title.lower()
                    matched_interests = []
                    for interest in interests:
                        keywords = _INTEREST_KEYWORDS.get(interest.lower(), [])
                        # Also match the interest name itself
                        if interest.lower() in title_lower:
                            matched_interests.append(interest)
                        elif any(kw in title_lower for kw in keywords):
                            matched_interests.append(interest)

                    if matched_interests or not interests:
                        # Include if it matches OR user has no interests
                        # (show top trends as fallback)
                        thumb_url = ""
                        description = ""
                        try:
                            slug = art.get("article", "")
                            sum_resp = await client.get(
                                f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{slug}",
                                headers={"User-Agent": "Virello/1.0"},
                                timeout=8.0,
                            )
                            if sum_resp.status_code == 200:
                                sum_data = sum_resp.json()
                                thumb = sum_data.get("thumbnail") or {}
                                thumb_url = thumb.get("source", "")
                                description = sum_data.get("description", "") or ""
                        except Exception:
                            pass

                        trends.append({
                            "query": title,
                            "source": "Wikipedia",
                            "type": "trend",
                            "detail": f"{views:,} views yesterday" if views else "",
                            "thumbnail_url": thumb_url,
                            "description": description,
                            "matched_interests": matched_interests,
                            "match_score": len(matched_interests),
                        })

                # Sort by match score (most interests matched first),
                # then by views
                trends.sort(key=lambda t: (t["match_score"], t.get("views", 0)),
                            reverse=True)
    except Exception:
        pass

    return {
        "recommendations": trends[:limit],
        "interests": interests,
        "note": (
            "Matched your interests against real Wikipedia trends using "
            "keyword matching. Honest heuristic — not deep AI."
        ),
    }
