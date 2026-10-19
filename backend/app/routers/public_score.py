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
    return {"score": score, "breakdown": breakdown, "tips": tips, "note": note,
            "mode": "ai"}


def _heuristic_score(text: str) -> dict:
    """Transparent offline fallback: scores measurable content signals only.
    Used when the AI provider is unavailable. Never presented as AI analysis."""
    import re
    t = text.strip()
    words = t.split()
    n_words = len(words)
    sentences = [s for s in re.split(r"[.!?\n]+", t) if s.strip()]
    first = t[:150]
    hashtags = re.findall(r"#\w+", t)
    emojis = len(re.findall(
        r"[\U0001F300-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF]", t))
    has_q = "?" in first
    has_num = bool(re.search(r"\d", first))
    cta_words = ("comment", "share", "follow", "save", "link in bio", "dm",
                 "subscribe", "tap", "click", "reply")
    has_cta = any(w in t.lower() for w in cta_words)
    you_count = len(re.findall(r"\byou\b", t.lower()))

    hook = 50
    if has_q:
        hook += 12
    if has_num:
        hook += 8
    if len(first) > 140:
        hook -= 12
    if n_words < 15:
        hook -= 10
    hook = max(5, min(98, hook))

    avg_sent = (n_words / max(1, len(sentences)))
    clarity = 70
    if avg_sent > 25:
        clarity -= 15
    if 8 <= avg_sent <= 20:
        clarity += 10
    if n_words < 10:
        clarity -= 15
    clarity = max(5, min(98, clarity))

    engagement = 45
    if has_cta:
        engagement += 18
    if you_count >= 2:
        engagement += 10
    if emojis and emojis <= 5:
        engagement += 8
    if emojis > 8:
        engagement -= 10
    engagement = max(5, min(98, engagement))

    discoverability = 50
    if 2 <= len(hashtags) <= 5:
        discoverability += 15
    elif len(hashtags) > 10:
        discoverability -= 12
    if n_words >= 40:
        discoverability += 8
    discoverability = max(5, min(98, discoverability))

    score = round(hook * 0.3 + clarity * 0.25 + engagement * 0.25
                  + discoverability * 0.2)
    tips = []
    if hook < 65:
        tips.append("Open with a question, a number, or a bold claim in the first line — most people only read that far.")
    if not has_cta:
        tips.append("Add one clear call-to-action: ask readers to comment, share, or save.")
    if not (2 <= len(hashtags) <= 5):
        tips.append("Use 2–5 relevant hashtags — none buries the post, too many looks spammy.")
    if avg_sent > 25:
        tips.append("Break long sentences into shorter ones — short lines get read, long ones get skipped.")
    if you_count < 2:
        tips.append("Speak directly to the reader ('you') — it lifts replies and saves.")
    tips = tips[:3] or ["Your draft is solid — test two hook variants and keep the winner."]
    return {
        "score": score,
        "breakdown": {"hook": hook, "clarity": clarity,
                      "engagement": engagement,
                      "discoverability": discoverability},
        "tips": tips,
        "note": "Instant signals estimate — AI deep analysis is temporarily offline.",
        "mode": "heuristic",
    }


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
        resp = None
    if resp is not None and not resp.dev:
        try:
            result = _parse_ai_json(resp.text)
        except Exception:
            result = None
        if result:
            result["platform"] = platform
            return result
    # AI unavailable (or answered via dev fallback) — honest offline estimate.
    result = _heuristic_score(body.text.strip())
    result["platform"] = platform
    return result
