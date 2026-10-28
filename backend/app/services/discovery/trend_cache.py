"""Cached trending feed for the app's Trending screen.

Problem (2026-10-28): ``GET /api/v1/discovery/trending`` aggregated
Wikimedia pageviews + Google News RSS *live on every request*, with one
Wikipedia summary HTTP call per article done SEQUENTIALLY. On Vercel
Hobby (10s function limit) that routinely blew the budget, so the app's
``TrendingScreen`` (which swallows errors into an empty list) showed its
empty state even though the sources are real and healthy.

Fix — cache-first, same honest sources, same response shape:
- One snapshot per (lang, geo) in ``discovery_trends_cache`` (see
  ``app.models.trending.DiscoveryTrendsCache``), TTL 1h. Fresh snapshot
  = served immediately, no upstream calls (<1s).
- On expiry the snapshot is refetched — with the per-article summary
  calls PARALLELIZED (asyncio.gather + semaphore) so the whole fetch
  fits the 10s budget — then stored and served.
- If the live fetch fails and a stale snapshot exists, the stale
  snapshot is served (marked ``stale: true``) instead of an empty
  list. Only when there is no snapshot at all does the endpoint
  return an empty ``trends`` list, exactly as before.

Every cache operation is defensive: a missing table, a failed
upsert, or a DB error never breaks the endpoint — it falls back to
the live fetch (and the live fetch itself never raises for partial
source failures). No fake data anywhere: every trend is a real
Wikipedia pageview rank or a real Google News headline.
"""
from __future__ import annotations

import asyncio
import json
import logging
import xml.etree.ElementTree as ET
from datetime import date, datetime, timedelta, timezone

import httpx
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.trending import DiscoveryTrendsCache
from app.services.discovery.trend_images import resolve_trend_thumbnails

log = logging.getLogger("virello.trending.cache")

# Snapshot freshness: Wikimedia's top-articles list is yesterday's data
# (stable all day); Google News headlines turn over faster. 1h keeps the
# app's feed fresh while bounding upstream calls to one per hour per
# (lang, geo). The app's max page size is 20 — the snapshot always holds
# 20 trends and the endpoint slices to the requested limit.
CACHE_TTL_SECONDS = 3600
CACHE_LIMIT = 20
_SUMMARY_CONCURRENCY = 6

TRENDS_NOTE = (
    "Real public attention signals (Wikipedia views + news headlines), "
    "not Virello posts. No data was fabricated."
)


def build_response(trends: list[dict], sources: list[str], lang: str) -> dict:
    """The /trending response shape (unchanged — the app reads ``trends``)."""
    return {
        "trends": trends,
        "sources": sources,
        "language": lang,
        "note": TRENDS_NOTE,
    }


# ------------------------------------------------------------------ cache


async def _ensure_cache_table(db: AsyncSession) -> None:
    """CREATE TABLE IF NOT EXISTS for the snapshot table. Never raises.

    Vercel never runs init_db (the serverless wrapper answers lifespan
    itself), so the endpoint path must be able to create its own table.
    Rolls back first: the thumbnail step shares this session across
    concurrent tasks, and a failed query there leaves the transaction
    broken — without the rollback the CREATE itself would die with
    PendingRollbackError and the table would never be created.
    """
    try:
        await db.rollback()
    except Exception:
        pass
    try:
        await db.execute(
            text(
                "CREATE TABLE IF NOT EXISTS discovery_trends_cache ("
                "lang TEXT NOT NULL, "
                "geo TEXT NOT NULL, "
                "payload TEXT NOT NULL, "
                "fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), "
                "PRIMARY KEY (lang, geo))"
            )
        )
        await db.commit()
    except Exception as exc:  # noqa: BLE001 — caching must never break trends
        log.warning("trend cache ensure failed: %s", exc)
        try:
            await db.rollback()
        except Exception:
            pass


async def read_trend_cache(
    db: AsyncSession, lang: str, geo: str
) -> tuple[dict, datetime] | None:
    """Return (payload, fetched_at) for a snapshot, or None.

    A missing table (or any DB error) returns None — the caller falls
    back to a live fetch. Never raises.
    """
    try:
        row = (
            await db.execute(
                select(DiscoveryTrendsCache).where(
                    DiscoveryTrendsCache.lang == lang,
                    DiscoveryTrendsCache.geo == geo,
                )
            )
        ).scalar_one_or_none()
    except Exception as exc:  # noqa: BLE001 — table may not exist yet
        log.warning("trend cache read failed (%s/%s): %s", lang, geo, exc)
        try:
            await db.rollback()
        except Exception:
            pass
        return None
    if row is None:
        return None
    try:
        payload = json.loads(row.payload or "{}")
    except (json.JSONDecodeError, TypeError):
        return None
    if not isinstance(payload, dict):
        return None
    fetched_at = row.fetched_at
    if fetched_at is not None and fetched_at.tzinfo is None:
        fetched_at = fetched_at.replace(tzinfo=timezone.utc)
    return payload, fetched_at


def cache_is_fresh(fetched_at: datetime | None) -> bool:
    """True when the snapshot was fetched within the TTL."""
    if fetched_at is None:
        return False
    age = (datetime.now(timezone.utc) - fetched_at).total_seconds()
    return 0 <= age < CACHE_TTL_SECONDS


async def write_trend_cache(
    db: AsyncSession, lang: str, geo: str, payload: dict
) -> tuple[bool, str]:
    """Upsert a snapshot. Returns (True, "") or (False, error)."""
    try:
        await _ensure_cache_table(db)
        row = (
            await db.execute(
                select(DiscoveryTrendsCache).where(
                    DiscoveryTrendsCache.lang == lang,
                    DiscoveryTrendsCache.geo == geo,
                )
            )
        ).scalar_one_or_none()
        blob = json.dumps(payload)
        now = datetime.now(timezone.utc)
        if row is None:
            db.add(
                DiscoveryTrendsCache(
                    lang=lang, geo=geo, payload=blob, fetched_at=now
                )
            )
        else:
            row.payload = blob
            row.fetched_at = now
        await db.commit()
        return True, ""
    except Exception as exc:  # noqa: BLE001 — caching must never break trends
        log.warning("trend cache write failed (%s/%s): %s", lang, geo, exc)
        try:
            await db.rollback()
        except Exception:
            pass
        return False, f"{type(exc).__name__}: {exc}"


# ------------------------------------------------------------------ live fetch


async def _fetch_summary(
    client: httpx.AsyncClient, lang: str, slug: str, sem: asyncio.Semaphore
) -> tuple[str, str]:
    """One Wikipedia summary fetch: (thumbnail_url, description)."""
    async with sem:
        try:
            resp = await client.get(
                f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{slug}",
                headers={"User-Agent": "Virello/1.0 (trends)"},
                timeout=3.0,
            )
            if resp.status_code == 200:
                data = resp.json()
                thumb = data.get("thumbnail") or {}
                return thumb.get("source", ""), data.get("description", "") or ""
        except Exception:
            pass
    return "", ""


async def fetch_trends_live(
    db: AsyncSession, geo: str = "US", limit: int = CACHE_LIMIT, lang: str = "en"
) -> tuple[list[dict], list[str]]:
    """Aggregate real trends from free public sources (no API keys).

    Same sources and filtering as the original live endpoint, but the
    per-article summary calls run CONCURRENTLY (they were sequential —
    the main reason the endpoint blew Vercel's 10s limit). Returns
    (trends, sources_used); never raises for partial source failures.
    """
    trends: list[dict] = []
    sources_used: list[str] = []

    # ---- Source 1: Wikimedia Top Articles (yesterday, real pageviews) ----
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
                headers={"User-Agent": "Virello/1.0 (trends; contact@virello.app)"},
            )
            candidates: list[tuple[str, str, int]] = []  # (title, slug, views)
            if resp.status_code == 200:
                data = resp.json()
                articles = data.get("items", [{}])[0].get("articles", [])
                for art in articles:
                    title = art.get("article", "").replace("_", " ").strip()
                    if not title or ":" in title or title.lower().startswith("main page"):
                        continue
                    if title.startswith(".") or len(title) < 3:
                        continue
                    candidates.append(
                        (title, art.get("article", ""), art.get("views", 0))
                    )
                    if len(candidates) >= limit:
                        break
            # Summaries for all candidates concurrently (was sequential).
            if candidates:
                sem = asyncio.Semaphore(_SUMMARY_CONCURRENCY)
                summaries = await asyncio.gather(
                    *(
                        _fetch_summary(client, lang, slug, sem)
                        for _, slug, _ in candidates
                    )
                )
                for (title, _slug, views), (thumb_url, description) in zip(
                    candidates, summaries
                ):
                    trends.append(
                        {
                            "query": title,
                            "source": "Wikipedia",
                            "geo": "Global",
                            "type": "trend",
                            "detail": f"{views:,} views yesterday" if views else "",
                            "thumbnail_url": thumb_url,
                            "description": description,
                        }
                    )
                if trends:
                    sources_used.append("Wikipedia Top Articles")
    except Exception as exc:
        log.warning("trending live fetch (wikipedia) failed: %s", exc)

    # ---- Source 2: Google News RSS (top headlines, fills remaining) ----
    if len(trends) < limit:
        try:
            news_url = (
                f"https://news.google.com/rss?hl=en-{geo.upper()}"
                f"&gl={geo.upper()}&ceid={geo.upper()}:en"
            )
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(news_url)
                if resp.status_code == 200:
                    root = ET.fromstring(resp.text)
                    for item in root.findall(".//item"):
                        if len(trends) >= limit:
                            break
                        title_elem = item.find("title")
                        source_elem = item.find("source")
                        link_elem = item.find("link")
                        if title_elem is not None and title_elem.text:
                            full = title_elem.text.strip()
                            headline = full.rsplit(" - ", 1)[0].strip()
                            src_name = (
                                source_elem.text.strip()
                                if source_elem is not None and source_elem.text
                                else "Google News"
                            )
                            article_url = (
                                link_elem.text.strip()
                                if link_elem is not None and link_elem.text
                                else ""
                            )
                            if headline and not any(
                                t["query"] == headline for t in trends
                            ):
                                trends.append(
                                    {
                                        "query": headline,
                                        "source": src_name,
                                        "geo": geo.upper(),
                                        "type": "news",
                                        "url": article_url,
                                    }
                                )
                    if any(t["type"] == "news" for t in trends):
                        sources_used.append("Google News")
        except Exception as exc:
            log.warning("trending live fetch (news) failed: %s", exc)

    # Fill display images for topics missing one: DB cache first, then
    # the real article og:image, then the real Wikipedia pageimage, then
    # a deterministic abstract illustration (person topics keep the
    # gradient fallback by design). Already parallel internally.
    try:
        await resolve_trend_thumbnails(trends, db, lang)
    except Exception as exc:
        log.warning("trend thumbnail resolution failed: %s", exc)
    # The thumbnail step shares this session across concurrent tasks; a
    # failed query there leaves the transaction broken. Clear it here —
    # the caller's cache write must not die on that stale state (each
    # cached image was already committed individually by the resolver).
    if db is not None:
        try:
            await db.rollback()
        except Exception:
            pass

    return trends[:limit], sources_used
