"""Analysis orchestration: fetch -> extract -> score -> cache.

Results are cached in post_analyses for 7 days (keyed by normalized URL)
so repeated campaigns on the same post don't re-fetch.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.growth import PostAnalysis
from .extract import (
    analyze_language_full, detect_language, detect_platform,
    extract_hashtags, extract_mentions, normalize_url,
)
from .fetcher import fetch_post
from .scoring import score_content

CACHE_DAYS = 7


async def get_cached_analysis(db: AsyncSession, url: str) -> PostAnalysis | None:
    norm = normalize_url(url)
    row = (await db.execute(
        select(PostAnalysis).where(PostAnalysis.url == norm))).scalar_one_or_none()
    if row is None:
        return None
    fresh_until = (row.analyzed_at or datetime.now(timezone.utc)).replace(
        tzinfo=timezone.utc) + timedelta(days=CACHE_DAYS)
    if datetime.now(timezone.utc) > fresh_until:
        return None
    return row


async def analyze_post(url: str, db: AsyncSession) -> PostAnalysis:
    norm = normalize_url(url)
    cached = await get_cached_analysis(db, url)
    if cached is not None:
        return cached

    platform = detect_platform(norm)
    fetched = await fetch_post(norm, platform)

    text = f"{fetched.title}\n{fetched.description}"
    hashtags = extract_hashtags(text)
    mentions = extract_mentions(text)
    language = detect_language(text)
    lang_full = analyze_language_full(text)
    signals = {
        "title_len": len(fetched.title),
        "description_len": len(fetched.description),
        "hashtag_count": len(hashtags),
        "mention_count": len(mentions),
        "fetch_level": fetched.level,
        "oembed_type": fetched.oembed_type,
    }
    score = score_content(
        title=fetched.title, description=fetched.description,
        hashtag_count=len(hashtags), media_type=fetched.media_type,
        has_thumbnail=bool(fetched.thumbnail_url), language=language)

    row = (await db.execute(
        select(PostAnalysis).where(PostAnalysis.url == norm))).scalar_one_or_none()
    if row is None:
        row = PostAnalysis(url=norm)
        db.add(row)
    row.platform = platform
    row.fetch_level = fetched.level
    row.title = fetched.title
    row.author = fetched.author
    row.description = fetched.description
    row.thumbnail_url = fetched.thumbnail_url
    row.media_type = fetched.media_type
    row.language = language
    row.language_metadata = lang_full
    row.concepts = lang_full.get("concepts", [])
    row.hashtags = hashtags
    row.mentions = mentions
    row.signals = signals
    row.score = score
    row.analyzed_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(row)
    return row


def analysis_summary(row: PostAnalysis) -> dict:
    """Compact dict for API responses and AI prompts."""
    return {
        "url": row.url, "platform": row.platform,
        "fetch_level": row.fetch_level, "title": row.title,
        "author": row.author, "description": row.description[:500],
        "thumbnail_url": row.thumbnail_url, "media_type": row.media_type,
        "language": row.language, "hashtags": row.hashtags,
        "language_metadata": row.language_metadata or {},
        "concepts": row.concepts or [],
        "signals": row.signals, "score": row.score,
        "analyzed_at": row.analyzed_at.isoformat() if row.analyzed_at else None,
    }
