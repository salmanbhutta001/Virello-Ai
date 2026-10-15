"""Virello Distribution Engine v1 — cross-platform content repurposing.

Legitimate distribution only: the user's OWN content, repurposed for THEIR
OWN connected accounts, one platform-optimized variant per platform.
Every variant carries the user's link/CTA following each platform's rules:
  - X / Facebook / YouTube: clickable URL inline (or in description).
  - Instagram / TikTok: captions can't carry clickable links, so the CTA
    says "link in bio" and names the link.
No fake engagement, no bots, no guaranteed reach — repurposing + honest CTAs.
"""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.services.ai.base import AIRequest, get_ai_provider

# Reuse the media router's proven AI pipeline: production provider first,
# Pollinations keyless fallback, plus its per-IP rate limiter.
from app.routers.media import _check_rate_limit, _pollinations_text

router = APIRouter()

PLATFORMS = ("instagram", "tiktok", "youtube", "x", "facebook")

# Per-platform caption rules. The link/CTA handling is the heart of v1:
# each platform gets the user's link in the form that platform supports.
_PLATFORM_SPECS = {
    "instagram": {
        "label": "Instagram",
        "rules": (
            "Write an Instagram caption: 60-140 words, warm and authentic, "
            "with line breaks for readability. End with 8-12 relevant hashtags "
            "on their own lines. Instagram captions do NOT support clickable "
            "links, so the call-to-action must say 'link in bio' and name the "
            "link — never paste a raw URL into the caption."
        ),
    },
    "tiktok": {
        "label": "TikTok",
        "rules": (
            "Write a TikTok caption: punchy, under 40 words, casual creator "
            "voice. End with 3-5 relevant hashtags. TikTok captions do NOT "
            "support clickable links, so the call-to-action must say "
            "'link in bio' — never paste a raw URL into the caption."
        ),
    },
    "youtube": {
        "label": "YouTube",
        "rules": (
            "Write a YouTube Shorts upload package. Format exactly as:\n"
            "TITLE: (one compelling title, max 70 characters)\n"
            "DESCRIPTION: (2-4 sentences describing the video, then the link "
            "as a full clickable URL on its own line — YouTube descriptions "
            "support clickable links)\n"
            "TAGS: (3-5 hashtags)"
        ),
    },
    "x": {
        "label": "X",
        "rules": (
            "Write an X post: the ENTIRE post including the link must fit in "
            "280 characters. Punchy, no fluff. Include the full clickable URL "
            "inline in the post text, plus 1-2 hashtags max. Count characters "
            "carefully — never exceed 280."
        ),
    },
    "facebook": {
        "label": "Facebook",
        "rules": (
            "Write a Facebook post: conversational, 40-90 words, like a real "
            "person sharing something. Include the full clickable URL inline "
            "in the post text (Facebook link previews work from inline URLs). "
            "2-4 hashtags max."
        ),
    },
}

_SYSTEM = (
    "You are Virello's Distribution Engine. Repurpose the user's content "
    "for ONE social platform, keeping their message and voice intact. "
    "Never invent statistics, earnings, guarantees, or fake claims. "
    "Output ONLY the platform-ready text — no explanations, no reasoning."
)


class RepurposeIn(BaseModel):
    content: str = Field(min_length=3, max_length=2000)
    link: str = Field(default="", max_length=300)
    platforms: list[str] = Field(default_factory=lambda: list(PLATFORMS))
    tone: str = Field(default="", max_length=60)


class VariantOut(BaseModel):
    platform: str
    label: str
    text: str


class RepurposeOut(BaseModel):
    variants: list[VariantOut]
    provider: str
    model: str


@router.post("/repurpose", response_model=RepurposeOut)
async def repurpose(body: RepurposeIn, request: Request):
    """Turn one piece of content + the user's link into platform-optimized
    variants. Production AI first, Pollinations fallback — labeled honestly."""
    _check_rate_limit(request, "distribution-repurpose")
    wanted = [p for p in body.platforms if p in _PLATFORM_SPECS] or list(PLATFORMS)
    link = body.link.strip()

    variants: list[VariantOut] = []
    provider_label, model = "pollinations", "pollinations-text"
    for platform in wanted:
        spec = _PLATFORM_SPECS[platform]
        user_prompt = f"Content to repurpose:\n{body.content.strip()}\n\n{spec['rules']}"
        if link:
            user_prompt += (
                f"\nThe user's link/CTA target: {link}. "
                "Include it exactly as the platform rules above require."
            )
        else:
            user_prompt += "\nNo link provided — end with a soft follow-for-more CTA instead."
        if body.tone:
            user_prompt += f"\nTone: {body.tone}."

        text, plabel, pmodel = None, "pollinations", "pollinations-text"
        try:
            provider = get_ai_provider()
            resp = await provider.complete(
                AIRequest(
                    agent="distribution_engine",
                    system=_SYSTEM,
                    user=user_prompt,
                    max_tokens=800,
                    temperature=0.8,
                )
            )
            if resp.text and not resp.dev:
                text, plabel, pmodel = resp.text.strip(), resp.provider, resp.model
        except Exception:
            text = None
        if not text:
            text = await _pollinations_text(_SYSTEM, user_prompt)
        if text:
            variants.append(VariantOut(platform=platform, label=spec["label"], text=text))
            provider_label, model = plabel, pmodel

    if not variants:
        raise HTTPException(
            status_code=503,
            detail="Distribution is unavailable right now. Please try again.",
        )
    return RepurposeOut(variants=variants, provider=provider_label, model=model)
