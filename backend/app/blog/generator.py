"""The daily article generator.

One attempt = one BlogRun row. Every gate that fails ends the attempt as
"skipped" with the reason in the run detail — the blog simply has no new
article that day, exactly like a human editor deciding not to publish.
"""
from __future__ import annotations

import json
import logging
import random
import re
import urllib.parse
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.blog import config
from app.blog.models import BlogPost, BlogRun
from app.models.commerce import Product

log = logging.getLogger("virello.blog.generator")

_SYSTEM = """You are the staff writer for Virello's blog (virelloai.online).
Write ONE complete, genuinely useful article as a JSON object.

Hard rules:
- 1500-1900 words of real depth. No filler, no fluff, no repetition.
- Honest and practical. NEVER promise virality, guaranteed followers or
  fixed results. No fake-engagement advice, no bots, no growth-hack folklore.
- Structure: compelling intro, 3-5 sections with <h3>/<h4> subheads,
  bullet/numbered lists where useful (as single strings containing the
  list HTML), an FAQ section (3-4 questions as <h3> + answer paragraphs),
  and a "bottom line" closing.
- Where internal links fit naturally, use <a href='#/features'>,
  <a href='#/how'> or <a href='#/pricing'>.
- The reader is a creator who posts on Instagram, TikTok, YouTube or X.

Return ONLY a JSON object with exactly these keys:
  title        — the article title (no quotes inside)
  category     — one of: AI Growth Tactics, AI Growth, Content, Analytics, Safety
  meta         — SEO meta description, 150-160 characters
  excerpt      — 1-2 sentence summary for the blog card
  image_prompt — a detailed illustration prompt for the header image
                 (photographic illustration, NO text in the image)
  body         — array of paragraph strings; subheads and lists are
                 strings containing inline HTML tags
"""


def slugify(title: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:80]
    return slug or "article"


def word_count(body: list) -> int:
    text = re.sub(r"<[^>]+>", " ", " ".join(str(p) for p in body))
    return len(text.split())


async def _pick_products(db: AsyncSession, dept: str) -> list[Product]:
    """Real catalog products for the affiliate weave-in (topic-matched
    department first, then the strongest trending products overall)."""
    q = (select(Product)
         .where(Product.is_affiliate.is_(True), Product.is_active.is_(True),
                Product.affiliate_url.is_not(None))
         .order_by(Product.trend_score.desc())
         .limit(2))
    rows = list((await db.execute(
        q.where(Product.category == dept))).scalars().all())
    if len(rows) < 2:
        seen = {p.id for p in rows}
        more = (await db.execute(q)).scalars().all()
        rows.extend(p for p in more if p.id not in seen)
    return rows[:2]


async def _unique_slug(db: AsyncSession, title: str) -> str:
    base = slugify(title)
    slug = base
    n = 2
    while (await db.execute(select(BlogPost.id).where(
            BlogPost.slug == slug))).scalar_one_or_none() is not None:
        slug = f"{base}-{n}"
        n += 1
    return slug


async def _make_image(slug: str, prompt: str) -> str | None:
    """Header image via Pollinations (text-to-image), stored on Cloudinary.
    Returns the live URL, or None when any step fails."""
    from app.curation.cloudinary_store import cloudinary_enabled, upload_image
    from app.curation.gallery import check_jpeg, download_bytes
    if not cloudinary_enabled():
        log.warning("blog image: cloudinary not configured — skipping")
        return None
    url = ("https://image.pollinations.ai/prompt/"
           + urllib.parse.quote(prompt)
           + "?model=flux&width=1200&height=630&nologo=true"
           + f"&seed={random.randint(1, 999_999_999)}")
    try:
        data = await download_bytes(url, timeout=120.0)
    except Exception as e:
        log.warning("blog image download failed: %s", type(e).__name__)
        return None
    ok, why = check_jpeg(data)
    if not ok:
        log.warning("blog image failed integrity check: %s", why)
        return None
    try:
        return await upload_image(data, f"blog_{slug}")
    except Exception as e:
        log.warning("blog image upload failed: %s", type(e).__name__)
        return None


async def generate_article(db: AsyncSession) -> dict:
    """One generation attempt. Returns the BlogRun summary dict."""
    run = BlogRun(status="running")
    db.add(run)
    await db.flush()

    async def skip(reason: str, provider: str = "") -> dict:
        run.status = "skipped"
        run.detail = reason
        run.provider = provider
        run.finished_at = datetime.now(timezone.utc)
        await db.commit()
        log.info("blog generation skipped: %s", reason)
        return {"status": "skipped", "reason": reason}

    total = (await db.execute(select(func.count(BlogPost.id)))).scalar() or 0
    theme, category, dept = config.TOPICS[total % len(config.TOPICS)]
    run.topic = theme
    titles = (await db.execute(
        select(BlogPost.title).order_by(BlogPost.published_at.desc())
        .limit(20))).scalars().all()

    products = await _pick_products(db, dept)
    product_lines = "\n".join(
        f"- {p.title} → {p.affiliate_url}" for p in products)
    user = (
        f"Write today's article on this brief:\n{theme}\n\n"
        f"Preferred category: {category}\n\n"
        "Existing article titles (never repeat or closely copy one):\n"
        + ("\n".join(f"- {t}" for t in titles) or "- (none yet)")
        + "\n\nAffiliate products you MAY weave in where they genuinely "
          "fit the topic (1-2 links maximum, as "
          "<a href='URL' target='_blank' rel='noopener sponsored'>name</a> "
          "inside a natural sentence; never force one):\n"
        + (product_lines or "- (none available)")
    )

    from app.services.ai.base import AIRequest, get_ai_provider
    provider = get_ai_provider()
    try:
        resp = await provider.complete(AIRequest(
            agent="blog_writer", system=_SYSTEM, user=user,
            max_tokens=8192, temperature=0.6, json_mode=True))
    except Exception as e:
        return await skip(f"AI provider call failed: {type(e).__name__}")
    if resp.dev:
        # The labeled dev/fallback output is a placeholder, not writing.
        return await skip(
            "AI provider unavailable (dev fallback answered) — no article "
            "published; check VIRELLO_AI_PROVIDER / provider key",
            provider=resp.provider)
    try:
        art = json.loads(resp.text)
    except (ValueError, TypeError):
        return await skip("AI response was not valid JSON",
                          provider=resp.provider)

    title = str(art.get("title") or "").strip()
    body = art.get("body")
    if not title or not isinstance(body, list) or len(body) < 10:
        return await skip("AI article failed structure check",
                          provider=resp.provider)
    body = [str(p) for p in body]
    words = word_count(body)
    if words < config.MIN_WORDS:
        return await skip(
            f"AI article too short ({words} words < {config.MIN_WORDS})",
            provider=resp.provider)
    cat = str(art.get("category") or "").strip()
    if cat not in config.CATEGORIES:
        cat = category if category in config.CATEGORIES else "AI Growth"

    slug = await _unique_slug(db, title)
    image_url = await _make_image(
        slug, str(art.get("image_prompt") or title))
    if not image_url:
        return await skip("header image could not be produced",
                          provider=resp.provider)

    links = sum(1 for p in products if p.affiliate_url
                and p.affiliate_url in " ".join(body))
    post = BlogPost(
        slug=slug, title=title[:300], category=cat,
        excerpt=str(art.get("excerpt") or "")[:600],
        meta_description=str(art.get("meta") or "")[:200],
        body=body, image_url=image_url,
        image_alt=str(art.get("image_prompt") or title)[:500],
        word_count=words,
        read_minutes=max(1, round(words / 200)),
        status="published", source="ai", provider=resp.provider,
        published_at=datetime.now(timezone.utc))
    db.add(post)
    run.status = "published"
    run.post_slug = slug
    run.provider = resp.provider
    run.detail = (f"{words} words, category={cat}, "
                  f"affiliate links woven in: {links}")
    run.finished_at = datetime.now(timezone.utc)
    await db.commit()
    log.info("blog article published: %s (%s words, %s)",
             slug, words, resp.provider)
    return {"status": "published", "slug": slug, "words": words,
            "provider": resp.provider, "affiliate_links": links}
