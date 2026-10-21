"""One-time migration: the articles that used to live inside the
website's index.html (seed_articles.json, extracted verbatim) become
BlogPost rows. Idempotent — does nothing when posts already exist.
"""
from __future__ import annotations

import json
import logging
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.blog.generator import slugify, word_count
from app.blog.models import BlogPost

log = logging.getLogger("virello.blog.seed")

_SEED_FILE = Path(__file__).resolve().parent / "seed_articles.json"
_MONTHS = {m: i + 1 for i, m in enumerate(
    ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"])}


def _parse_label(label: str) -> datetime:
    m = re.match(r"([A-Za-z]{3}) (\d{4})", (label or "").strip())
    if m and m.group(1) in _MONTHS:
        return datetime(int(m.group(2)), _MONTHS[m.group(1)], 1,
                        tzinfo=timezone.utc)
    return datetime(2026, 1, 1, tzinfo=timezone.utc)


async def seed_blog_posts(db: AsyncSession) -> int:
    existing = (await db.execute(
        select(func.count(BlogPost.id)))).scalar() or 0
    if existing:
        return 0
    try:
        articles = json.loads(_SEED_FILE.read_text(encoding="utf-8"))
    except Exception as e:
        log.warning("blog seed file unreadable: %s", e)
        return 0
    total = len(articles)
    created = 0
    used_slugs: set[str] = set()
    for idx, a in enumerate(articles):
        title = str(a.get("title") or "").strip()
        if not title:
            continue
        slug = slugify(title)
        base, n = slug, 2
        while slug in used_slugs:
            slug = f"{base}-{n}"
            n += 1
        used_slugs.add(slug)
        body = [str(p) for p in (a.get("body") or [])]
        words = word_count(body)
        mins = re.search(r"(\d+)", str(a.get("mins") or ""))
        img = a.get("img") or {}
        # Array order is newest-first; stagger the days inside the
        # label month so the API ordering reproduces it exactly.
        published = _parse_label(str(a.get("date") or "")) + timedelta(
            days=(total - idx))
        db.add(BlogPost(
            slug=slug, title=title,
            category=str(a.get("cat") or "AI Growth"),
            excerpt=str(a.get("excerpt") or ""),
            meta_description=str(a.get("meta") or ""),
            body=body,
            image_url=str(img.get("src") or ""),
            image_alt=str(img.get("alt") or title),
            word_count=words,
            read_minutes=int(mins.group(1)) if mins else max(
                1, round(words / 200)),
            status="published", source="seed",
            published_at=published))
        created += 1
    await db.commit()
    log.info("blog seed: %d articles migrated from the website", created)
    return created
