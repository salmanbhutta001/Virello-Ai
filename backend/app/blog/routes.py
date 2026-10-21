"""Blog HTTP surface.

Public (no auth — the website reads these):
- GET /api/v1/blog/posts           list, newest first, without bodies
- GET /api/v1/blog/posts/{slug}    one full article

Operator (admin login OR X-Curator-Token, same rule as curation):
- GET  /api/v1/blog/status         last run + counts
- POST /api/v1/blog/run            write today's article now (background)
- POST /api/v1/blog/posts          publish an article by hand
"""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.blog import config
from app.blog.generator import slugify, word_count
from app.blog.models import BlogPost, BlogRun
from app.core.deps import get_db
from app.curation.routes import _require_admin_or_curator

log = logging.getLogger("virello.blog.routes")
router = APIRouter()


def _labels(post: BlogPost) -> dict:
    """The exact shape the website blog UI renders."""
    return {
        "slug": post.slug,
        "cat": post.category,
        "title": post.title,
        "mins": f"{post.read_minutes} min read",
        "date": post.published_at.strftime("%b %Y"),
        "img": {"src": post.image_url, "alt": post.image_alt},
        "meta": post.meta_description,
        "excerpt": post.excerpt,
    }


@router.get("/api/v1/blog/posts")
async def list_posts(limit: int = 30, offset: int = 0,
                     db: AsyncSession = Depends(get_db)) -> dict:
    limit = min(max(limit, 1), 100)
    offset = max(offset, 0)
    total = (await db.execute(
        select(func.count(BlogPost.id))
        .where(BlogPost.status == "published"))).scalar() or 0
    rows = (await db.execute(
        select(BlogPost).where(BlogPost.status == "published")
        .order_by(BlogPost.published_at.desc())
        .limit(limit).offset(offset))).scalars().all()
    return {"posts": [_labels(p) for p in rows], "total": int(total)}


@router.get("/api/v1/blog/posts/{slug}")
async def get_post(slug: str, db: AsyncSession = Depends(get_db)) -> dict:
    post = (await db.execute(
        select(BlogPost).where(BlogPost.slug == slug,
                               BlogPost.status == "published")
    )).scalar_one_or_none()
    if post is None:
        raise HTTPException(404, "Article not found")
    out = _labels(post)
    out["body"] = post.body or []
    out["published_at"] = post.published_at.isoformat()
    return out


@router.get("/api/v1/blog/status")
async def blog_status(request: Request,
                      db: AsyncSession = Depends(get_db)) -> dict:
    await _require_admin_or_curator(request, db)
    last = (await db.execute(
        select(BlogRun).order_by(BlogRun.started_at.desc()).limit(1)
    )).scalar_one_or_none()
    total = (await db.execute(
        select(func.count(BlogPost.id))
        .where(BlogPost.status == "published"))).scalar() or 0
    return {
        "enabled": config.blog_enabled(),
        "schedule": f"daily {config.blog_hour():02d}:{config.blog_minute():02d} Asia/Karachi",
        "published_posts": int(total),
        "next_topic": config.TOPICS[int(total) % len(config.TOPICS)][0],
        "last_run": None if last is None else {
            "started_at": last.started_at.isoformat() if last.started_at else None,
            "finished_at": last.finished_at.isoformat() if last.finished_at else None,
            "status": last.status,
            "topic": last.topic,
            "post_slug": last.post_slug,
            "detail": last.detail,
            "provider": last.provider,
        },
    }


_run_lock = asyncio.Lock()


async def _run_once() -> None:
    from app.blog.generator import generate_article
    from app.core.database import SessionLocal
    try:
        async with SessionLocal() as db:
            result = await generate_article(db)
        log.info("manual blog run finished: %s", result)
    except Exception:
        log.exception("manual blog run crashed")
    finally:
        if _run_lock.locked():
            _run_lock.release()


@router.post("/api/v1/blog/run")
async def blog_run_now(request: Request,
                       db: AsyncSession = Depends(get_db)) -> dict:
    """Write today's article immediately, in the background."""
    await _require_admin_or_curator(request, db)
    if _run_lock.locked():
        raise HTTPException(409, "A blog generation is already running")
    await _run_lock.acquire()
    asyncio.create_task(_run_once())
    return {"started": True,
            "note": "Generation running — watch GET /api/v1/blog/status."}


class PostIn(BaseModel):
    title: str = Field(..., max_length=300)
    category: str = Field(default="AI Growth", max_length=60)
    excerpt: str = Field(default="", max_length=600)
    meta_description: str = Field(default="", max_length=200)
    body: list[str] = Field(..., min_length=1)
    image_url: str = Field(default="", max_length=1000)
    image_alt: str = Field(default="", max_length=500)


@router.post("/api/v1/blog/posts", status_code=201)
async def create_post(payload: PostIn, request: Request,
                      db: AsyncSession = Depends(get_db)) -> dict:
    """Publish an article by hand — no agent or deploy needed."""
    await _require_admin_or_curator(request, db)
    base = slugify(payload.title)
    slug = base
    n = 2
    while (await db.execute(select(BlogPost.id).where(
            BlogPost.slug == slug))).scalar_one_or_none() is not None:
        slug = f"{base}-{n}"
        n += 1
    words = word_count(payload.body)
    post = BlogPost(
        slug=slug, title=payload.title.strip(), category=payload.category,
        excerpt=payload.excerpt, meta_description=payload.meta_description,
        body=payload.body, image_url=payload.image_url,
        image_alt=payload.image_alt or payload.title,
        word_count=words, read_minutes=max(1, round(words / 200)),
        status="published", source="manual",
        published_at=datetime.now(timezone.utc))
    db.add(post)
    await db.commit()
    return {"slug": slug, "created": True}
