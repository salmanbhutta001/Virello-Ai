"""Trending topic images: generate per-topic artwork, store on Cloudinary.

Pipeline per topic:
    1. Try Agnes AI image generation (VIRELLO_AGNES_API_KEY).
    2. Download the result and re-upload to Cloudinary (folder
       ``virello/trending``) so URLs are permanent and CDN-fast.
    3. If generation fails: build a branded Virello placeholder with PIL
       (gradient + topic title) and upload that instead.
    4. If Cloudinary is not configured: return "" (DB stores empty,
       same convention as the seed data).

Security: no credentials are ever logged. Public IDs are slugified from
the topic title + a date stamp so reruns overwrite the same asset.
"""
from __future__ import annotations

import io
import logging
import re
import time
from datetime import date

import httpx

log = logging.getLogger("virello.trending.images")

HTTP_TIMEOUT = 60.0


def _slug(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return (slug or "topic")[:48]


# ------------------------------------------------------------------ Agnes


async def _agnes_generate(topic_title: str, category: str) -> bytes | None:
    """Generate image bytes via Agnes AI. Returns None on any failure."""
    try:
        from app.services.agnes_client import agnes_image_generate
    except Exception as exc:
        log.warning("trending images: agnes client unavailable: %s", exc)
        return None
    prompt = (
        f"Modern flat illustration representing the trending topic "
        f"'{topic_title}' ({category}), vibrant gradient background, "
        f"no text, no watermark, social media thumbnail style"
    )
    try:
        url = await agnes_image_generate(
            prompt=prompt,
            style_suffix="clean vector style, high quality",
            seed=None,
        )
    except Exception as exc:
        log.warning("trending images: agnes generate failed for %r: %s", topic_title, exc)
        return None
    if not url:
        return None
    try:
        async with httpx.AsyncClient(timeout=HTTP_TIMEOUT, follow_redirects=True) as client:
            r = await client.get(url)
            r.raise_for_status()
            data = r.content
    except Exception as exc:
        log.warning("trending images: download failed for %r: %s", topic_title, exc)
        return None
    if not data or len(data) < 1024:
        return None
    return data


# ------------------------------------------------------- branded fallback


def _placeholder_jpeg(topic_title: str, category: str) -> bytes:
    """Build a branded 1200x630 JPEG: Virello gradient + topic title.

    Pure PIL, no external calls — guaranteed to work offline.
    """
    from PIL import Image, ImageDraw, ImageFont

    W, H = 1200, 630
    top = (99, 102, 241)      # indigo
    bottom = (168, 85, 247)   # purple
    img = Image.new("RGB", (W, H), top)
    draw = ImageDraw.Draw(img)
    for y in range(H):  # vertical gradient
        r = int(top[0] + (bottom[0] - top[0]) * y / H)
        g = int(top[1] + (bottom[1] - top[1]) * y / H)
        b = int(top[2] + (bottom[2] - top[2]) * y / H)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # "V" watermark circle
    draw.ellipse([W - 260, 60, W - 60, 260], outline=(255, 255, 255), width=6)
    try:
        font_big = ImageFont.truetype("DejaVuSans-Bold.ttf", 64)
        font_small = ImageFont.truetype("DejaVuSans.ttf", 34)
        font_v = ImageFont.truetype("DejaVuSans-Bold.ttf", 110)
    except OSError:
        font_big = font_small = font_v = ImageFont.load_default()

    draw.text((W - 215, 105), "V", font=font_v, fill=(255, 255, 255))
    draw.text((80, 60), "VIRELLO  •  TRENDING NOW", font=font_small,
              fill=(255, 255, 255))

    # Wrap the title to fit
    words, lines, line = topic_title.split(), [], ""
    for w in words:
        trial = (line + " " + w).strip()
        if draw.textlength(trial, font=font_big) < W - 160:
            line = trial
        else:
            lines.append(line)
            line = w
    if line:
        lines.append(line)
    lines = lines[:3]
    y = 190
    for ln in lines:
        draw.text((80, y), ln, font=font_big, fill=(255, 255, 255))
        y += 84
    draw.text((80, y + 20), category.upper(), font=font_small,
              fill=(230, 230, 255))

    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=85)
    return buf.getvalue()


# ------------------------------------------------------------------ main


async def generate_topic_image(topic_title: str, category: str = "general") -> str:
    """Create and store a topic image. Returns the Cloudinary URL or "".

    Tries Agnes AI first, falls back to a branded PIL placeholder.
    Returns "" when Cloudinary is not configured (caller stores empty).
    """
    from app.curation.cloudinary_store import cloudinary_enabled, upload_image

    if not cloudinary_enabled():
        log.info("trending images: cloudinary not configured, skipping image")
        return ""

    data = await _agnes_generate(topic_title, category)
    made_by = "agnes"
    if data is None:
        log.info("trending images: using branded placeholder for %r", topic_title)
        data = _placeholder_jpeg(topic_title, category)
        made_by = "placeholder"

    # Normalize to JPEG >= 640px on the short edge (Cloudinary/gallery rule).
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(data)).convert("RGB")
        w, h = img.size
        short = min(w, h)
        if short < 640:
            scale = 640 / short
            img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=85)
        data = buf.getvalue()
    except Exception as exc:
        log.warning("trending images: jpeg normalize failed: %s", exc)
        # continue with raw bytes; upload may still succeed

    public_id = f"trending_{_slug(topic_title)}_{date.today():%Y%m%d}"
    try:
        url = await upload_image(data, public_id, folder="virello/trending")
    except Exception as exc:
        log.warning("trending images: cloudinary upload failed (%s): %s", made_by, exc)
        return ""
    log.info("trending images: %s image stored for %r", made_by, topic_title)
    return url
