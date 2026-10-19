"""Public Free AI Post Score endpoint for virelloai.online.

POST /api/v1/public/score {text, platform} -> {score, breakdown, tips, note}
No authentication (it's the website's free tool). Light per-IP rate limiting
guards the AI provider budget. Never promises virality — scores content-quality
signals only.
"""
from __future__ import annotations

import json
import time
from collections import defaultdict, deque

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.services.ai.base import AIRequest, get_ai_provider

router = APIRouter()

# 10 AI scorings / hour / IP — generous for humans, useless for scrapers.
_LIMIT, _WINDOW = 10, 3600
_hits: dict[str, deque] = defaultdict(deque)

_PLATFORMS = {"instagram", "tiktok", "youtube", "x", "facebook"}


class ScoreIn(BaseModel):
    text: str = Field(min_length=10, max_length=2000)
    platform: str = Field(default="instagram", max_length=20)


_SYSTEM = (
    "You are Virello's content-analysis agent. Score the social media post draft "
    "below from 0 to 100 on content-quality signals only.\n"
    "Return ONLY a JSON object with this exact shape:\n"
    '{"score": <0-100 integer>, '
    '"breakdown": {"hook": <0-100>, "clarity": <0-100>, "engagement": <0-100>, "discoverability": <0-100>}, '
    '"tips": ["<3 short actionable improvements, each under 20 words>"], '
    '"note": "<one-line honest caveat>"}\n'
    "Rules: never promise virality, followers, reach, or sales. Never claim guaranteed "
    "results. Be strict but fair. Keep tips concrete and specific to this draft."
)


def _rate_limit(request: Request) -> None:
    ip = request.client.host if request.client else "unknown"
    key = ip + ":public-score"
    now = time.monotonic()
    dq = _hits[key]
    while dq and now - dq[0] > _WINDOW:
        dq.popleft()
    if len(dq) >= _LIMIT:
        raise HTTPException(
            status_code=429,
            detail="Free limit reached (10 scores/hour). Try again later.",
        )
    dq.append(now)


def _parse_ai_json(text: str) -> dict:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        if cleaned.lower().startswith("json"):
            cleaned = cleaned[4:]
    data = json.loads(cleaned)
    score = max(0, min(100, int(data["score"])))
    breakdown = {}
    for k in ("hook", "clarity", "engagement", "discoverability"):
        breakdown[k] = max(0, min(100, int(data.get("breakdown", {}).get(k, 50))))
    tips = [str(t)[:140] for t in data.get("tips", [])][:3]
    note = str(data.get("note", ""))[:200]
    return {"score": score, "breakdown": breakdown, "tips": tips, "note": note}


@router.post("/score")
async def public_score(body: ScoreIn, request: Request) -> dict:
    _rate_limit(request)
    platform = body.platform.lower().strip()
    if platform not in _PLATFORMS:
        platform = "instagram"
    provider = get_ai_provider()
    try:
        resp = await provider.complete(
            AIRequest(
                agent="content_analysis",
                system=_SYSTEM,
                user=f"Platform: {platform}\nPost draft:\n{body.text.strip()}",
                max_tokens=600,
                temperature=0.3,
                json_mode=True,
            )
        )
    except Exception:
        raise HTTPException(
            status_code=502,
            detail="AI analysis is temporarily unavailable. Please try again in a minute.",
        )
    if resp.dev:
        # Dev provider is never real analysis — fail closed, don't fake a score.
        raise HTTPException(
            status_code=503,
            detail="AI analysis is temporarily unavailable. Please try again later.",
        )
    try:
        result = _parse_ai_json(resp.text)
    except Exception:
        raise HTTPException(
            status_code=502,
            detail="Could not score this post. Please try again.",
        )
    result["platform"] = platform
    return result
