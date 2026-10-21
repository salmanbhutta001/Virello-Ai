"""AI Entertainment API — Phase 6 of the Virello evolution.

Original uplifting short stories and comic ideas via the AI provider ABC.
Every response carries dev/provider labels; provider failures return
honest 502s — output is never faked.
"""
from __future__ import annotations

import json
import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.core import User
from app.services.ai.base import (
    AIProviderError,
    AIProviderNotConfigured,
    AIRequest,
    get_claude_first_provider,
)

router = APIRouter(prefix="/entertain", tags=["entertain"])


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------
class StoryIn(BaseModel):
    topic: str | None = Field(default=None, max_length=200)
    prompt: str | None = Field(default=None, max_length=1000)
    length: str = Field(default="short", pattern="^(short|medium|long)$")
    language: str = Field(default="en", pattern="^(en|ur|ar)$")


class StoryOut(BaseModel):
    title: str
    body: str


class StoryResponse(BaseModel):
    story: StoryOut
    dev: bool
    provider: str | None = None


class ComicIn(BaseModel):
    topic: str = Field(..., min_length=2, max_length=200)
    panels: int = Field(default=4, ge=2, le=6)
    language: str = Field(default="en", pattern="^(en|ur|ar)$")


class ComicPanel(BaseModel):
    panel: int
    description: str
    caption: str


class ComicOut(BaseModel):
    title: str
    panels: list[ComicPanel]


class ComicResponse(BaseModel):
    comic: ComicOut
    dev: bool
    provider: str | None = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_TITLE_RE = re.compile(r"^\s*(?:title\s*:\s*)", re.IGNORECASE)


def _split_title(body: str) -> tuple[str, str]:
    """Split a provider story into (title, body); strip a 'Title:' prefix.

    If the provider returns something that doesn't look like a titled
    story (e.g. a raw JSON blob from the dev provider), fall back to a
    generic title rather than using garbage as the title. The body is
    always returned verbatim and stays dev-labeled by the caller.
    """
    text = (body or "").strip()
    if not text:
        raise ValueError("empty story text")
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    first = _TITLE_RE.sub("", lines[0]) if lines else ""
    if first.startswith(("{", "<")) or len(first) > 90 or len(lines) < 2:
        # No usable title line — derive one from the first sentence,
        # or fall back to generic.
        sentence = re.split(r"[.!؟\n]", first)[0].strip()
        if sentence[:1] in ("{", "<") or len(sentence) <= 12:
            return "Untitled Story", text
        return sentence[:70], text
    title = first
    rest = "\n".join(lines[1:]).strip()
    return title or "Untitled Story", rest or text


def _validate_comic(payload: dict, panels: int) -> ComicOut:
    if not isinstance(payload, dict):
        raise ValueError("provider returned non-object JSON")
    title = str(payload.get("title", "")).strip() or "Untitled Comic"
    raw_panels = payload.get("panels")
    if not isinstance(raw_panels, list) or len(raw_panels) != panels:
        raise ValueError(f"expected exactly {panels} panels")
    out: list[ComicPanel] = []
    for i, p in enumerate(raw_panels, start=1):
        if not isinstance(p, dict) or not p.get("description") or not p.get("caption"):
            raise ValueError("each panel needs description + caption")
        out.append(
            ComicPanel(
                panel=int(p.get("panel", i)),
                description=str(p["description"]),
                caption=str(p["caption"]),
            )
        )
    return ComicOut(title=title, panels=out)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
_STORY_SYSTEM = (
    "You write short original uplifting stories. Never reproduce copyrighted "
    "text. Start with a short title line, then the story. Keep it kind and "
    "original."
)


@router.post("/story", response_model=StoryResponse)
async def write_story(
    body: StoryIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    subject = body.topic or body.prompt or "a small act of kindness"
    words = {"short": "~150-word", "medium": "~350-word", "long": "~600-word"}.get(body.length, "~350-word")
    max_tok = {"short": 1500, "medium": 2500, "long": 3500}.get(body.length, 2500)
    provider = get_claude_first_provider()
    try:
        resp = await provider.complete(
            AIRequest(
                agent="entertainment",
                system=_STORY_SYSTEM,
                user=(f"Write a {words} original short story about: {subject}. "
                      f"Language: {body.language}."),
                max_tokens=max_tok,
                temperature=0.8,
                json_mode=False,
            )
        )
    except (AIProviderError, AIProviderNotConfigured) as exc:
        raise HTTPException(502, f"AI provider failed: {exc}") from exc
    except Exception as exc:
        raise HTTPException(502, f"AI provider failed: {exc}") from exc
    try:
        title, story_body = _split_title(resp.text)
    except ValueError as exc:
        raise HTTPException(502, f"AI provider returned an unusable story: {exc}") from exc
    return StoryResponse(
        story=StoryOut(title=title, body=story_body),
        dev=bool(resp.dev),
        provider=resp.provider,
    )


_COMIC_SYSTEM = (
    "You create original comic strip ideas. Never reproduce copyrighted "
    "characters or dialogue. Respond with ONLY a JSON object."
)


@router.post("/comic-idea", response_model=ComicResponse)
async def comic_idea(
    body: ComicIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    provider = get_claude_first_provider()
    try:
        resp = await provider.complete(
            AIRequest(
                agent="entertainment",
                system=_COMIC_SYSTEM,
                user=(f"Create an original {body.panels}-panel comic strip idea about: "
                      f"{body.topic}. Language: {body.language}. Return ONLY valid JSON "
                      f"with this exact shape: {{\"title\": \"...\", "
                      f"\"panels\": [{{\"panel\": 1, \"description\": \"visual scene\", "
                      f"\"caption\": \"dialogue/caption\"}}, ... exactly {body.panels} panels]}}."),
                max_tokens=1500,
                temperature=0.8,
                json_mode=True,
            )
        )
    except (AIProviderError, AIProviderNotConfigured) as exc:
        raise HTTPException(502, f"AI provider failed: {exc}") from exc
    except Exception as exc:
        raise HTTPException(502, f"AI provider failed: {exc}") from exc
    try:
        comic = _validate_comic(json.loads(resp.text), body.panels)
    except (json.JSONDecodeError, ValueError) as exc:
        raise HTTPException(
            502, f"AI provider returned an invalid comic idea: {exc}"
        ) from exc
    return ComicResponse(comic=comic, dev=bool(resp.dev), provider=resp.provider)
