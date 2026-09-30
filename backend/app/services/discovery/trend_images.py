"""Resolve a display image for trending topics.

Resolution order (truthfulness first):
  1. Real Wikipedia pageimage via ``action=query&prop=pageimages`` — a real
     photo of the topic beats anything generated.
  2. DB cache (``trend_image_cache``) — a topic is resolved once, never on
     every Trending load.
  3. Stylized thematic illustration via the keyless Pollinations
     text-to-image endpoint (the same built-in generation family the app
     uses elsewhere). The prompt is deliberately ABSTRACT — geometric
     shapes only, never a depiction of a person.

Hard rule: a topic that is (or looks like) a real person's name NEVER gets
a generated image when no real photo exists — a fabricated face next to a
real person's name is deceptive, stylized or not. Those cards keep the
built-in gradient fallback.

The public ``/trending`` shape is unchanged: ``thumbnail_url`` is filled
when an image is available. The mobile already renders ``thumbnail_url``
(gradient fallback otherwise), so no client changes are needed, and no
AI labels/badges are added anywhere (silent-intelligence rule).
"""
from __future__ import annotations

import asyncio
import hashlib
import logging
import re
import urllib.parse

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.discovery import TrendImageCache

log = logging.getLogger(__name__)

_WIKI_UA = "Virello/1.0 (trend-images; contact@virello.app)"

# Topics already being generated in the background — avoids duplicate work
# when many users open Trending at once.
_in_flight: set[str] = set()

# 2-3 capitalized Latin words: "Christa Pike", "Case Keenum". Conservative
# person-name signal (non-Latin names fall through to the category check).
_PERSON_NAME_RE = re.compile(r"^[A-Z][a-z]+(?: [A-Z][a-z]+){1,2}$")

# Wikipedia category markers of a biography article (English edition).
_PERSON_CATEGORIES = ("birth", "death", "living people")


def topic_key(query: str) -> str:
    """Normalized cache key for a trend query."""
    return " ".join((query or "").lower().strip().split())[:200]


def _stable_seed(key: str) -> int:
    """Deterministic seed per topic so a generated URL is stable/cached."""
    return int(hashlib.sha256(key.encode()).hexdigest(), 16) % 1_000_000_000


async def get_cached_image(db: AsyncSession, key: str) -> TrendImageCache | None:
    row = await db.execute(
        select(TrendImageCache).where(TrendImageCache.topic_key == key)
    )
    return row.scalar_one_or_none()


async def put_cached_image(db: AsyncSession, key: str, image_url: str, kind: str) -> None:
    existing = await get_cached_image(db, key)
    if existing:
        existing.image_url = image_url
        existing.kind = kind
    else:
        db.add(TrendImageCache(topic_key=key, image_url=image_url, kind=kind))
    await db.commit()


def looks_like_person_name(query: str) -> bool:
    """Conservative heuristic: 2-3 capitalized Latin words, e.g. 'Christa Pike'."""
    return bool(_PERSON_NAME_RE.match((query or "").strip()))


async def wikipedia_topic_info(query: str, lang: str = "en",
                               timeout: float = 8.0) -> dict:
    """Real photo + person signals for a topic.

    Returns ``{"image_url": str, "is_person": bool}``. ``image_url`` is the
    real Wikipedia pageimage ("" when the page has none). ``is_person`` is
    True when the article's categories mark it as a biography.
    """
    info = {"image_url": "", "is_person": False}
    title = (query or "").strip()
    if not title:
        return info
    lang = (lang or "en").lower().strip()[:3] or "en"
    if not lang.isalpha():
        lang = "en"
    params = {
        "action": "query",
        "format": "json",
        "prop": "pageimages|categories",
        "pithumbsize": 800,
        "cllimit": 30,
        "titles": title,
    }
    url = f"https://{lang}.wikipedia.org/w/api.php?" + urllib.parse.urlencode(params)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.get(url, headers={"User-Agent": _WIKI_UA})
            if resp.status_code != 200:
                return info
            pages = resp.json().get("query", {}).get("pages", {})
            for page in pages.values():
                if page.get("missing") is not None:
                    continue
                thumb = page.get("thumbnail") or {}
                src = thumb.get("source", "")
                if src.startswith("http"):
                    info["image_url"] = src
                cats = " ".join(
                    c.get("title", "") for c in page.get("categories", [])
                ).lower()
                if any(marker in cats for marker in _PERSON_CATEGORIES):
                    info["is_person"] = True
                break  # titles= takes one title; first real page wins
    except Exception as e:
        log.debug("wikipedia topic info miss for %r: %s", title, e)
    return info


async def fetch_wikipedia_pageimage(query: str, lang: str = "en",
                                     timeout: float = 8.0) -> str:
    """Real topic photo via Wikipedia pageimages API. Returns URL or ""."""
    return (await wikipedia_topic_info(query, lang=lang, timeout=timeout))["image_url"]


def thematic_prompt(query: str) -> str:
    """Abstract, honest illustration prompt — never a depiction of anyone.

    Pure geometric composition: the art is clearly symbolic, so it can
    never be mistaken for a photograph — or any likeness — of a person,
    place, or event.
    """
    topic = " ".join((query or "").strip().split())[:120] or "trending topic"
    return (
        f"Pure abstract geometric composition, flat vector illustration, "
        f"concept art inspired by the theme '{topic}'. Soft gradients, "
        f"symbolic shapes, modern minimal editorial style. Absolutely no "
        f"photorealism, no real people, no human figures, no bodies, "
        f"no silhouettes of people, no faces, no portraits, no text, "
        f"no words, no letters, no logos, no watermarks."
    )


def pollinations_t2i_url(prompt: str, seed: int) -> str:
    """Keyless text-to-image URL (built-in generation, same family the app uses)."""
    q = urllib.parse.quote
    return (
        "https://image.pollinations.ai/prompt/" + q(prompt)
        + "?model=flux&width=1024&height=1024&nologo=true"
        + f"&seed={seed}"
    )


def generated_image_url(key: str, query: str) -> str:
    """Deterministic generated-image URL for a topic (stable across loads)."""
    return pollinations_t2i_url(thematic_prompt(query), _stable_seed(key))


async def _generate_and_cache(key: str, query: str) -> None:
    """Background: generate the thematic illustration, verify, cache it."""
    if key in _in_flight:
        return
    _in_flight.add(key)
    try:
        from app.core.database import SessionLocal
        from app.curation.gallery import check_jpeg, download_bytes

        url = generated_image_url(key, query)
        try:
            data = await download_bytes(url, timeout=150.0)
        except Exception as e:
            log.info("trend image generation failed for %r: %s", query, e)
            return
        ok, reason = check_jpeg(data)
        if not ok:
            log.info("trend image failed verification for %r: %s", query, reason)
            return
        async with SessionLocal() as db:
            await put_cached_image(db, key, url, "generated")
        log.info("cached generated trend image for %r", query)
    finally:
        _in_flight.discard(key)


async def _resolve_one(query: str, lang: str, db: AsyncSession) -> str:
    """Return a thumbnail URL for one topic ("" when none available yet)."""
    key = topic_key(query)
    if not key:
        return ""
    cached = await get_cached_image(db, key)
    if cached and cached.image_url:
        return cached.image_url
    info = await wikipedia_topic_info(query, lang=lang)
    if info["image_url"]:
        await put_cached_image(db, key, info["image_url"], "wikipedia")
        return info["image_url"]
    if info["is_person"] or looks_like_person_name(query):
        # Never fabricate a likeness of a real person: no real photo, no
        # generated image. The card keeps the built-in gradient fallback.
        log.info("skipping generated image for person topic %r", query)
        return ""
    # No real photo and not a person: generate a purely abstract thematic
    # illustration in the background so the request stays fast; the card
    # shows it on the next load.
    asyncio.create_task(_generate_and_cache(key, query))
    return ""


async def resolve_trend_thumbnails(trends: list[dict], db: AsyncSession,
                                   lang: str = "en") -> None:
    """Fill missing ``thumbnail_url`` on trend dicts, in place.

    Only topics without a thumbnail are touched; everything is cached so
    repeated loads never re-resolve. Wikipedia lookups run in parallel.
    """
    pending = [t for t in trends if not (t.get("thumbnail_url") or "").strip()]
    if not pending:
        return
    results = await asyncio.gather(
        *(_resolve_one(t.get("query", ""), lang, db) for t in pending)
    )
    for trend, url in zip(pending, results):
        if url:
            trend["thumbnail_url"] = url
