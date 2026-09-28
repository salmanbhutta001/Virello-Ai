"""Viral Lab API — Phase 2 of the Virello evolution.

POST /analysis/improve    {post_url?|text?} -> score + per-area improvement
                                            suggestions (heuristic, explainable)
POST /analysis/variations {post_url?|text?, count=3} -> original content
                                            variations with different angles

All suggestions are heuristic/development-labeled until a production AI
provider is configured. Never promises virality, reach or sales.
"""
from __future__ import annotations

import json
import logging
import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.services.ai.base import AIRequest, get_ai_provider
from app.services.analysis.extract import (
    detect_language,
    extract_hashtags,
)
from app.services.analysis.scoring import DISCLAIMER, score_content
from app.services.analysis.service import analyze_post, analysis_summary

logger = logging.getLogger(__name__)
router = APIRouter()

DEV_NOTE = (
    "Development preview — heuristic output. "
    "Connect a production AI provider for richer suggestions."
)

# ---------------------------------------------------------------------------
# Improvement suggestions: deterministic heuristics from score components
# ---------------------------------------------------------------------------

_AREA_INFO = {
    "hook": ("Opening hook", "Does the first line grab attention?"),
    "clarity": ("Clarity", "Is the message the right length and readable?"),
    "hashtags": ("Hashtags", "Are tags in the healthy 2-8 range?"),
    "media": ("Media", "Is there a thumbnail or video?"),
    "cta": ("Call to action", "Is the viewer told what to do next?"),
    "language": ("Language", "Can the target audience read it?"),
}

_SUGGESTIONS = {
    "hook": (
        "Start with a question, a number, or a bold first line "
        "(e.g. 'Stop doing this…', '3 mistakes…', 'POV: …'). "
        "The first 60 characters decide whether people keep reading."
    ),
    "clarity": (
        "Aim for 40-220 characters for the main caption: one clear idea, "
        "short sentences, no filler. Cut anything that doesn't serve the point."
    ),
    "hashtags": (
        "Use 2-8 relevant hashtags. Fewer than 2 limits discovery; "
        "more than 8 looks spammy and dilutes each tag."
    ),
    "media": (
        "Posts with a thumbnail or video consistently present better. "
        "Add a clear cover image or short video if the platform supports it."
    ),
    "cta": (
        "Add one clear call to action: 'Save this', 'Follow for part 2', "
        "'Link in bio' — tell the viewer exactly what to do next."
    ),
    "language": (
        "Write in the language your audience reads natively. "
        "Mixed or undetectable language lowers comprehension."
    ),
}


def _component_key(area: str) -> str:
    return {
        "hook": "hook", "clarity": "clarity", "hashtags": "hashtag_hygiene",
        "media": "media", "cta": "cta", "language": "language_fit",
    }[area]


def build_improvements(components: dict) -> list[dict]:
    """Deterministic improvement list from score components."""
    out: list[dict] = []
    for area in ("hook", "clarity", "hashtags", "media", "cta", "language"):
        score = int(components.get(_component_key(area), 0))
        if score >= 70:
            continue
        title, current_hint = _AREA_INFO[area]
        out.append({
            "area": area,
            "title": title,
            "current": f"{current_hint} Current score: {score}/100.",
            "suggestion": _SUGGESTIONS[area],
            "priority": "high" if score < 40 else "medium",
            "score": score,
        })
    out.sort(key=lambda x: x["score"])
    return out


def heuristic_rewritten_hook(text: str) -> str:
    """A deterministic example rewrite of the opening line (labeled heuristic)."""
    first = (text or "").strip().split("\n")[0].strip()
    first = re.sub(r"\s+", " ", first)
    if not first:
        return "Stop scrolling — here's what actually works…"
    if len(first) > 70:
        first = first[:67].rstrip() + "…"
    return f"Stop doing this: {first[0].lower() + first[1:] if len(first) > 1 else first}"


def _score_text_directly(text: str) -> dict:
    """Score raw pasted text without fetching a URL."""
    text = (text or "").strip()
    hashtags = extract_hashtags(text)
    language = detect_language(text)
    return score_content(
        title=text[:120], description=text,
        hashtag_count=len(hashtags), media_type="link",
        has_thumbnail=False, language=language)


# ---------------------------------------------------------------------------
# Variations: original rewrites at different angles (never copied content)
# ---------------------------------------------------------------------------

_ANGLES = ("question", "numbered", "story", "bold", "howto")

_ANGLE_WHY = {
    "question": "Questions invite the viewer to answer in comments.",
    "numbered": "Numbered lists promise a quick, scannable payoff.",
    "story": "A personal moment makes the post feel human, not corporate.",
    "bold": "A strong statement stops the scroll — then you back it up.",
    "howto": "'How to' framing promises practical value up front.",
}


def heuristic_variations(text: str, count: int) -> list[dict]:
    """Deterministic angle-based rewrites (labeled heuristic)."""
    core = re.sub(r"\s+", " ", (text or "").strip())
    if len(core) > 140:
        core = core[:137].rstrip() + "…"
    if not core:
        core = "your idea"
    low = core[0].lower() + core[1:] if len(core) > 1 else core
    templates = {
        "question": f"What if {low} — would you try it?",
        "numbered": f"3 things I learned about {low}",
        "story": f"I used to struggle with {low}. Here's what changed…",
        "bold": f"Unpopular opinion: {low} is overrated. Here's why…",
        "howto": f"How to get better at {low} (in 60 seconds)",
    }
    out = []
    for angle in _ANGLES[: max(1, min(count, len(_ANGLES)))]:
        out.append({
            "text": templates[angle],
            "angle": angle,
            "why_it_works": _ANGLE_WHY[angle],
        })
    return out


async def _ai_variations(text: str, count: int, language: str) -> list[dict] | None:
    """Try the live AI provider; return None to fall back to heuristics."""
    prov = get_ai_provider()
    # Peek: the dev provider is deterministic-template; use heuristics directly.
    if prov.name == "dev":
        return None
    system = (
        "You are Virello's Viral Lab. Write ORIGINAL short social-post "
        "variations of the user's text, each from a different angle "
        "(question, numbered list, story, bold statement, how-to). "
        f"Reply in language '{language}'. Never promise virality, reach or sales. "
        "Return ONLY a JSON object: "
        '{"variations": [{"text": "...", "angle": "...", "why_it_works": "..."}]}'
    )
    try:
        resp = await prov.complete(AIRequest(
            agent="viral_lab", system=system,
            user=f"Original text: {text}\nCount: {count}",
            max_tokens=900, temperature=0.8, json_mode=True))
        data = json.loads(resp.text)
        items = data.get("variations") or []
        out = []
        for it in items[:count]:
            if isinstance(it, dict) and it.get("text"):
                out.append({
                    "text": str(it["text"])[:500],
                    "angle": str(it.get("angle", "variation"))[:40],
                    "why_it_works": str(it.get("why_it_works", ""))[:300],
                })
        return out or None
    except Exception as exc:  # fail closed -> heuristics
        logger.warning("viral_lab provider failed: %s", exc)
        return None


# ---------------------------------------------------------------------------
# Request/response models
# ---------------------------------------------------------------------------

class ImproveIn(BaseModel):
    post_url: str | None = None
    text: str | None = None


class VariationsIn(BaseModel):
    post_url: str | None = None
    text: str | None = None
    count: int = Field(default=3, ge=1, le=5)


async def _resolve_input(body_post_url: str | None, body_text: str | None,
                        db: AsyncSession) -> tuple[str, dict | None]:
    """Return (text, analysis_summary_or_None)."""
    url = (body_post_url or "").strip()
    text = (body_text or "").strip()
    if url:
        if not url.lower().startswith(("http://", "https://")):
            raise HTTPException(400, "Provide a public http(s) post URL")
        row = await analyze_post(url, db)
        summary = analysis_summary(row)
        full_text = f"{row.title or ''}\n{row.description or ''}".strip()
        return full_text or url, summary
    if text:
        return text, None
    raise HTTPException(400, "Provide post_url or text")


@router.post("/improve")
async def improve(body: ImproveIn, db: AsyncSession = Depends(get_db),
                  _user: User = Depends(get_current_user)) -> dict:
    text, summary = await _resolve_input(body.post_url, body.text, db)
    if summary is not None:
        score = summary["score"]
        components = score["components"]
    else:
        scored = _score_text_directly(text)
        score, components = scored["score"], scored["components"]
    improvements = build_improvements(components)
    prov = get_ai_provider()
    return {
        "score": score,
        "components": components,
        "improvements": improvements,
        "rewritten_hook": heuristic_rewritten_hook(text),
        "dev": prov.name == "dev",
        "provider": prov.name,
        "dev_note": DEV_NOTE if prov.name == "dev" else None,
        "disclaimer": DISCLAIMER,
        "analysis": summary,
    }


@router.post("/variations")
async def variations(body: VariationsIn, db: AsyncSession = Depends(get_db),
                     _user: User = Depends(get_current_user)) -> dict:
    text, _summary = await _resolve_input(body.post_url, body.text, db)
    language = detect_language(text)
    items = await _ai_variations(text, body.count, language)
    dev = items is None
    if dev:
        items = heuristic_variations(text, body.count)
    prov = get_ai_provider()
    return {
        "variations": items,
        "count": len(items),
        "dev": dev or prov.name == "dev",
        "provider": prov.name,
        "dev_note": DEV_NOTE if (dev or prov.name == "dev") else None,
        "disclaimer": (
            "Original variations to edit and make your own — "
            "not a prediction or guarantee of reach, virality, or sales."
        ),
    }
