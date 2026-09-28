"""AI Content Creation API — Phase 3 of the Virello evolution (text-first).

POST /create/ideas    {topic, count?, language?} -> content ideas
POST /create/scripts  {topic, format?, language?} -> script (hook/body/cta)
POST /create/captions {topic, platform?, language?} -> captions + hashtags
POST /create/hooks    {topic, count?, language?} -> opening hooks

All generation goes through the AI provider ABC. The dev provider returns
deterministic heuristic templates, always labeled. No media (image/video/
voice) generation yet — text only, honestly.
"""
from __future__ import annotations

import json
import logging
import random

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.services.ai.base import AIRequest, get_ai_provider

logger = logging.getLogger(__name__)
router = APIRouter()

DEV_NOTE = (
    "Development preview — heuristic output. "
    "Connect a production AI provider for richer generation."
)

_DISCLAIMER = (
    "Original starting points to edit and make your own — "
    "not a prediction or guarantee of reach, virality, or sales."
)

_LANG_NAMES = {"en": "English", "ur": "Urdu", "ar": "Arabic"}


def _lang(code: str | None) -> str:
    code = (code or "en").lower()
    return code if code in _LANG_NAMES else "en"


# ---------------------------------------------------------------------------
# Heuristic (dev) generators — deterministic templates, always labeled
# ---------------------------------------------------------------------------

_IDEA_FORMATS = ["short video", "carousel", "talking-head reel", "text post", "tutorial clip"]


def _heuristic_ideas(topic: str, count: int) -> list[dict]:
    topic = topic.strip() or "your niche"
    angles = [
        ("myth-busting", f"3 myths about {topic} (busted)"),
        ("beginner guide", f"{topic} for absolute beginners"),
        ("mistakes", f"5 mistakes everyone makes with {topic}"),
        ("behind the scenes", f"A day working on {topic}"),
        ("transformation", f"{topic}: before vs after"),
        ("quick tips", f"{topic} in 60 seconds"),
        ("story", f"How I got into {topic}"),
        ("comparison", f"{topic} vs the alternative — honest take"),
    ]
    out = []
    for i, (angle, title) in enumerate(angles[: max(1, min(count, len(angles)))]):
        out.append({
            "title": title,
            "format": _IDEA_FORMATS[i % len(_IDEA_FORMATS)],
            "angle": angle,
            "brief": f"Hook viewers with the {angle} angle, deliver one clear takeaway about {topic}, end with a question.",
        })
    return out


def _heuristic_script(topic: str, format: str) -> dict:
    topic = topic.strip() or "your niche"
    format = (format or "video").lower()
    if format not in ("video", "reel", "post"):
        format = "video"
    beats = 5 if format in ("video", "reel") else 3
    return {
        "topic": topic,
        "format": format,
        "hook": f"Stop scrolling — here's the one thing about {topic} nobody tells you…",
        "body": [
            f"Beat {i + 1}: one clear point about {topic} (keep it under 10 seconds)."
            for i in range(beats)
        ],
        "cta": "Follow for part 2 — and tell me your experience in the comments.",
    }


def _heuristic_captions(topic: str, platform: str | None) -> list[dict]:
    topic = topic.strip() or "your niche"
    tag_base = "".join(c for c in topic.lower() if c.isalnum())
    tags = [f"#{tag_base}", "#contentcreator", "#tips", "#learnontiktok", "#viral"]
    return [
        {
            "caption": f"Everything I wish I knew about {topic} 👇\n\nSave this for later — part 2 drops tomorrow.",
            "hashtags": tags[:5],
            "tone": "helpful",
        },
        {
            "caption": f"POV: you finally understand {topic} 😅\n\nTag someone who needs this.",
            "hashtags": tags[:4],
            "tone": "playful",
        },
        {
            "caption": f"{topic.capitalize()} — explained in 30 seconds.\n\nFollow for daily breakdowns.",
            "hashtags": tags[:3],
            "tone": "direct",
        },
    ]


def _heuristic_hooks(topic: str, count: int) -> list[str]:
    topic = (topic.strip() or "this").rstrip(".")
    templates = [
        f"Stop doing {topic} wrong — do this instead…",
        f"The {topic} trick nobody talks about 👀",
        f"I tried {topic} for 30 days. Here's what happened…",
        f"3 {topic} mistakes that are costing you…",
        f"POV: you finally master {topic}",
        f"Why 99% of people fail at {topic}…",
        f"{topic} explained so simply a 5-year-old gets it…",
    ]
    return templates[: max(1, min(count, len(templates)))]


# ---------------------------------------------------------------------------
# Live-provider path (JSON mode, strict parse, heuristic fallback)
# ---------------------------------------------------------------------------

async def _ai_json(agent: str, system: str, user: str,
                   max_tokens: int = 900) -> tuple[dict | None, str, bool]:
    """Return (parsed_json_or_None, provider_name, dev)."""
    prov = get_ai_provider()
    if prov.name == "dev":
        return None, prov.name, True
    try:
        resp = await prov.complete(AIRequest(
            agent=agent, system=system, user=user,
            max_tokens=max_tokens, temperature=0.8, json_mode=True))
        data = json.loads(resp.text)
        return (data if isinstance(data, dict) else None,
                resp.provider, bool(resp.dev))
    except Exception as exc:  # fail closed -> heuristics
        logger.warning("create provider failed: %s", exc)
        return None, prov.name, True


def _envelope(payload: dict, provider: str, dev: bool) -> dict:
    payload["provider"] = provider
    payload["dev"] = dev
    payload["dev_note"] = DEV_NOTE if dev else None
    payload["disclaimer"] = _DISCLAIMER
    return payload


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

class IdeasIn(BaseModel):
    topic: str
    count: int = Field(default=5, ge=1, le=8)
    language: str | None = None


@router.post("/ideas")
async def ideas(body: IdeasIn, db: AsyncSession = Depends(get_db),
                _user: User = Depends(get_current_user)) -> dict:
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant. Generate original short content "
        f"ideas in {_LANG_NAMES[lang]}. Return ONLY JSON: "
        '{"ideas": [{"title": "...", "format": "...", "angle": "...", "brief": "..."}]}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nCount: {body.count}")
    items = None
    if data:
        raw = data.get("ideas") or []
        items = [i for i in raw if isinstance(i, dict) and i.get("title")][: body.count]
    if not items:
        items = _heuristic_ideas(body.topic, body.count)
        dev = True
    return _envelope({"ideas": items, "count": len(items)}, provider, dev)


class ScriptIn(BaseModel):
    topic: str
    format: str = "video"  # video | reel | post
    language: str | None = None


@router.post("/scripts")
async def scripts(body: ScriptIn, db: AsyncSession = Depends(get_db),
                  _user: User = Depends(get_current_user)) -> dict:
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant writing in {_LANG_NAMES[lang]}. "
        "Return ONLY JSON: "
        '{"hook": "...", "body": ["beat 1", "beat 2", ...], "cta": "..."}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nFormat: {body.format}")
    script = None
    if data and data.get("hook") and isinstance(data.get("body"), list):
        script = {"topic": body.topic, "format": body.format,
                  "hook": str(data["hook"])[:300],
                  "body": [str(b)[:300] for b in data["body"][:8]],
                  "cta": str(data.get("cta", ""))[:300]}
    if not script:
        script = _heuristic_script(body.topic, body.format)
        dev = True
    return _envelope({"script": script}, provider, dev)


class CaptionsIn(BaseModel):
    topic: str
    platform: str | None = None
    language: str | None = None


@router.post("/captions")
async def captions(body: CaptionsIn, db: AsyncSession = Depends(get_db),
                   _user: User = Depends(get_current_user)) -> dict:
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant writing in {_LANG_NAMES[lang]}. "
        "Return ONLY JSON: "
        '{"captions": [{"caption": "...", "hashtags": ["#a"], "tone": "..."}]}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nPlatform: {body.platform or 'any'}")
    items = None
    if data:
        raw = data.get("captions") or []
        items = [c for c in raw if isinstance(c, dict) and c.get("caption")][:5]
    if not items:
        items = _heuristic_captions(body.topic, body.platform)
        dev = True
    return _envelope({"captions": items, "count": len(items)}, provider, dev)


class HooksIn(BaseModel):
    topic: str
    count: int = Field(default=5, ge=1, le=7)
    language: str | None = None


@router.post("/hooks")
async def hooks(body: HooksIn, db: AsyncSession = Depends(get_db),
                _user: User = Depends(get_current_user)) -> dict:
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant writing in {_LANG_NAMES[lang]}. "
        'Return ONLY JSON: {"hooks": ["...", "..."]}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nCount: {body.count}")
    items = None
    if data and isinstance(data.get("hooks"), list):
        items = [str(h)[:200] for h in data["hooks"] if h][: body.count]
    if not items:
        items = _heuristic_hooks(body.topic, body.count)
        dev = True
    return _envelope({"hooks": items, "count": len(items)}, provider, dev)
