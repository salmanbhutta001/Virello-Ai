"""Creator Hub media API — real generation endpoints.

- POST /api/v1/media/generate-image   — real AI image via the configured
  ImageProvider (default: Pollinations.ai, free/keyless, modular).
- POST /api/v1/media/generate-caption — real AI hook/caption/hashtags via
  the configured AIProvider (Groq/OpenAI/Anthropic/Google, else dev).

Both are PUBLIC: Creator Hub is free on all plans (no credit deduction).
A light per-IP rate limit guards the shared provider quota. Failures are
reported honestly — never a fake placeholder.
"""
from __future__ import annotations

import json
import time
from collections import defaultdict, deque

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.services.ai.base import AIRequest, get_ai_provider
from app.services.image_provider import (
    ImageProviderError,
    ImageProviderNotConfigured,
    ImageRequest,
    get_image_provider,
)

router = APIRouter()

# --- light per-IP rate limiting (in-memory; single-instance friendly) ---
_RATE_LIMITS = {
    "generate-image": (30, 3600),    # 30 images / hour / IP
    "generate-caption": (60, 3600),  # 60 captions / hour / IP
}
_hits: dict[str, deque] = defaultdict(deque)


def _check_rate_limit(request: Request, key: str) -> None:
    limit, window = _RATE_LIMITS[key]
    ip = (request.client.host if request.client else "unknown") + ":" + key
    now = time.monotonic()
    dq = _hits[ip]
    while dq and now - dq[0] > window:
        dq.popleft()
    if len(dq) >= limit:
        raise HTTPException(
            status_code=429,
            detail=f"Rate limit reached ({limit}/hour). Try again later.",
        )
    dq.append(now)


_ASPECTS = {
    "4:5": (864, 1080),
    "9:16": (810, 1440),
    "1:1": (1080, 1080),
}


class GenerateImageIn(BaseModel):
    prompt: str = Field(min_length=3, max_length=600)
    aspect: str = Field(default="4:5")


class GenerateImageOut(BaseModel):
    image_url: str
    provider: str
    model: str
    width: int
    height: int


@router.post("/generate-image", response_model=GenerateImageOut)
async def generate_image(body: GenerateImageIn, request: Request):
    """Generate a real AI image for the Creator Hub Image Studio."""
    _check_rate_limit(request, "generate-image")
    width, height = _ASPECTS.get(body.aspect, _ASPECTS["4:5"])
    try:
        provider = get_image_provider()
    except ImageProviderNotConfigured as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    try:
        # Vary the seed per call so "Regenerate" gives a fresh image.
        seed = int(time.time() * 1000) % 999983
        result = await provider.generate(
            ImageRequest(prompt=body.prompt, width=width, height=height, seed=seed)
        )
    except ImageProviderError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Image generation failed: {exc}. Please try again.",
        )
    return GenerateImageOut(
        image_url=result.image_url,
        provider=result.provider,
        model=result.model,
        width=result.width,
        height=result.height,
    )


class GenerateCaptionIn(BaseModel):
    topic: str = Field(min_length=3, max_length=500)
    niche: str = Field(default="", max_length=80)
    goal: str = Field(default="", max_length=80)


class GenerateCaptionOut(BaseModel):
    hook: str
    caption: str
    hashtags: list[str]
    provider: str
    model: str
    dev: bool = False


_CAPTION_SYSTEM = """You are Virello's Caption & Hook Writer, an expert social-media
copywriter for Instagram Reels, TikTok and YouTube Shorts. Write in the
creator's voice: punchy, authentic, no corporate fluff, no fake claims.
Never invent statistics, earnings or guarantees. Respond with a JSON object
containing exactly these keys: "hook" (one scroll-stopping opening line,
max 15 words), "caption" (2-4 short lines, emoji sparingly, ends with a
soft CTA like save/share), "hashtags" (array of 8-12 relevant hashtag
strings WITHOUT the # character, mixing niche and broad tags)."""


@router.post("/generate-caption", response_model=GenerateCaptionOut)
async def generate_caption(body: GenerateCaptionIn, request: Request):
    """Write a real AI hook + caption + hashtags for the Creator Hub."""
    _check_rate_limit(request, "generate-caption")
    user_prompt = f"Topic: {body.topic}"
    if body.niche:
        user_prompt += f"\nNiche: {body.niche}"
    if body.goal:
        user_prompt += f"\nGoal: {body.goal}"
    try:
        provider = get_ai_provider()
    except Exception as exc:
        raise HTTPException(
            status_code=502, detail=f"AI provider init failed: {type(exc).__name__}"
        )
    try:
        resp = await provider.complete(
            AIRequest(
                agent="caption_writer",
                system=_CAPTION_SYSTEM,
                user=user_prompt,
                max_tokens=600,
                temperature=0.8,
                json_mode=True,
            )
        )
    except HTTPException:
        raise
    except Exception as exc:  # provider errors -> honest 502, never fake text
        raise HTTPException(
            status_code=502,
            detail=f"Caption generation failed ({type(exc).__name__}): {str(exc)[:120]}",
        )
    try:
        data = json.loads(resp.text)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=502, detail="Caption generation returned bad data."
        )
    # Fail closed on the dev provider: its template has no hook/caption keys,
    # and we never serve empty or template text as a "generated" caption.
    if resp.dev or not str(data.get("hook", "")).strip():
        raise HTTPException(
            status_code=503,
            detail="AI caption writer is not configured (no production AI provider).",
        )
    hashtags = data.get("hashtags") or []
    hashtags = [str(h).lstrip("#").strip() for h in hashtags][:12]
    return GenerateCaptionOut(
        hook=str(data.get("hook", "")).strip(),
        caption=str(data.get("caption", "")).strip(),
        hashtags=hashtags,
        provider=resp.provider,
        model=resp.model,
        dev=resp.dev,
    )
