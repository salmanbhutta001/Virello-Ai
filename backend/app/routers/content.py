"""Link -> Native Content Transformer (free organic growth strategy #1).

Paste a link (or raw text) and get native content drafts for each target
platform: a short-form video script, a carousel, a thread, and a story
caption. Every draft is built from the fetched source only — never
invented — and the original link appears ONLY inside CTA fields.

Honesty rules (non-negotiable):
- No fake engagement, no bots, no fake metrics.
- Never promise reach, virality, followers, or sales. Output is drafts
  only, labeled "ai" or "heuristic".
- If the AI provider is unavailable or its output fails validation, we
  fall back to deterministic heuristic templates and say so.
"""
from __future__ import annotations

import re
from typing import Any
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.deps import get_current_user
from app.models.core import User
from app.services import growth_ai
from app.services.ai.base import AIProviderError, AIProviderNotConfigured
from app.services.analysis import fetcher

try:  # reuse the product-wide honesty guardrail when available
    from app.routers.ai import honesty_check
except Exception:  # pragma: no cover - defensive fallback
    def honesty_check(text: str) -> bool:  # type: ignore[no-redef]
        return "guaranteed viral" not in text.lower()

router = APIRouter()

PLATFORMS = ("instagram", "tiktok", "youtube", "facebook", "x")

NOTE = (
    "These are content drafts only — not reach or virality estimates. "
    "No platform guarantees how a post will perform; consistent posting "
    "and genuinely engaging your audience is what builds growth over time."
)

_SENT_SPLIT = re.compile(r"(?<=[.!?])\s+")


class TransformIn(BaseModel):
    url: str | None = None
    text: str | None = None
    platforms: list[str] = Field(default_factory=lambda: list(PLATFORMS))

    @field_validator("platforms")
    @classmethod
    def _valid_platforms(cls, v: list[str]) -> list[str]:
        cleaned: list[str] = []
        for p in v:
            name = (p or "").strip().lower()
            if name not in PLATFORMS:
                raise ValueError(
                    f"unknown platform {p!r}; choose from: "
                    + ", ".join(PLATFORMS))
            if name not in cleaned:
                cleaned.append(name)
        return cleaned or list(PLATFORMS)  # empty list = all platforms

    @model_validator(mode="after")
    def _url_or_text(self) -> "TransformIn":
        if not (self.url or "").strip() and not (self.text or "").strip():
            raise ValueError("Provide either 'url' or 'text'.")
        return self


# ------------------------------------------------------------------ helpers
def _platform_from_host(host: str) -> str:
    h = host.lower()
    if "youtube" in h or "youtu.be" in h:
        return "youtube"
    if "tiktok" in h:
        return "tiktok"
    if "instagram" in h:
        return "instagram"
    if h.endswith("x.com") or "twitter" in h:
        return "twitter"
    if "facebook" in h or h.startswith("fb."):
        return "facebook"
    return "link"


def _domain(host: str) -> str:
    h = host.lower()
    return h[4:] if h.startswith("www.") else h


def _sentences(text: str) -> list[str]:
    return [s.strip() for s in _SENT_SPLIT.split((text or "").strip())
            if s.strip()]


def _clip(text: str, limit: int) -> str:
    t = (text or "").strip()
    if len(t) <= limit:
        return t
    return t[:limit].rsplit(" ", 1)[0].rstrip() + "…"


# Per-platform flavor knobs: beats count, carousel size, thread size,
# per-post cap. Nothing here is a performance claim — just formatting.
_PLATFORM_STYLE: dict[str, dict[str, Any]] = {
    "instagram": {"beats": 4, "slides": 6, "posts": 5, "post_max": 400},
    "tiktok":    {"beats": 4, "slides": 5, "posts": 4, "post_max": 220},
    "youtube":   {"beats": 5, "slides": 6, "posts": 4, "post_max": 600},
    "facebook":  {"beats": 4, "slides": 6, "posts": 5, "post_max": 600},
    "x":         {"beats": 3, "slides": 4, "posts": 5, "post_max": 280},
}


def _cta(url: str | None) -> str:
    if url:
        return f"🔗 Full story here: {url}"
    return "💾 Save this for later so you don't lose it."


def _heuristic_formats(platform: str, title: str,
                       sentences: list[str], url: str | None) -> dict:
    """Deterministic templates built only from the source material."""
    style = _PLATFORM_STYLE[platform]
    topic = _clip(title, 60) or "this"
    cta = _cta(url)

    hook = f"POV: you finally hear the real story behind “{topic}” 👀"
    beats = [_clip(s, 140) for s in sentences[:style["beats"]]]
    if not beats:
        beats = ["Here's the key idea, in plain words."]

    slides = [f"COVER — {topic}"]
    for i, s in enumerate(sentences[: style["slides"] - 2], start=1):
        slides.append(f"{i}. {_clip(s, 120)}")
    slides.append(f"CTA — {cta}")  # link lives ONLY here

    posts = [_clip(f"🧵 {_clip(sentences[0], 100)}" if sentences
                   else f"🧵 {topic}", style["post_max"])]
    for i, s in enumerate(sentences[1: style["posts"] - 1], start=2):
        posts.append(_clip(f"{i}/{style['posts'] - 1} {s}",
                           style["post_max"]))
    posts.append(cta)  # link lives ONLY here

    story_caption = f"{_clip(hook, 120)}\n\n{cta}"

    return {
        "video_script": {"hook": hook, "beats": beats, "cta": cta},
        "carousel": {"slides": slides},
        "thread": {"posts": posts},
        "story_caption": story_caption,
    }


# ------------------------------------------------------------------ AI path
_SYSTEM_TRANSFORM = (
    "You are Virello's content transformer. You turn a SOURCE (a fetched "
    "title + description, or user-pasted text) into native content DRAFTS "
    "for social platforms. Reply with STRICT JSON only, no prose:\n"
    '{"platforms": [{"platform": "<one of instagram|tiktok|youtube|facebook|x>", '
    '"formats": {"video_script": {"hook": str, "beats": [str], "cta": str}, '
    '"carousel": {"slides": [str]}, "thread": {"posts": [str]}, '
    '"story_caption": str}}]}\n'
    "Rules: (1) drafts only — NEVER promise reach, virality, followers, "
    "sales, or any outcome; never use the word 'guaranteed'; "
    "(2) never invent facts not present in SOURCE; "
    "(3) the original link may appear ONLY inside CTA fields "
    "(video_script.cta, the LAST carousel slide, the LAST thread post, "
    "the end of story_caption); (4) keep hooks punchy and honest."
)


def _transform_user_prompt(source_text: str, url: str | None,
                           platforms: list[str]) -> str:
    link_line = (f"ORIGINAL LINK: {url}\n(use it ONLY in CTA fields, "
                 f"nowhere else)") if url else \
                "ORIGINAL LINK: none (no link in input — CTAs must not invent one)"
    return (
        f"SOURCE:\n{_clip(source_text, 2000)}\n\n{link_line}\n\n"
        f"Build drafts for exactly these platforms, in this order: "
        f"{', '.join(platforms)}"
    )


class _SchemaViolation(Exception):
    pass


def _jstr(value: Any, key: str, *, max_len: int) -> str:
    if not isinstance(value, str) or not value.strip():
        raise _SchemaViolation(f"{key}: expected non-empty string")
    if len(value) > max_len:
        raise _SchemaViolation(f"{key}: exceeds {max_len} chars")
    return value


def _jlist(value: Any, key: str, *, min_items: int,
           max_items: int, item_max: int) -> list[str]:
    if not isinstance(value, list) or not (min_items <= len(value) <= max_items):
        raise _SchemaViolation(f"{key}: expected {min_items}..{max_items} items")
    out = []
    for i, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            raise _SchemaViolation(f"{key}[{i}]: expected non-empty string")
        if len(item) > item_max:
            raise _SchemaViolation(f"{key}[{i}]: exceeds {item_max} chars")
        out.append(item)
    return out


def _validate_transform_payload(payload: Any,
                                platforms: list[str]) -> list[dict] | None:
    """Strict-validate AI output; None on ANY problem -> heuristic fallback."""
    try:
        if not isinstance(payload, dict) or not isinstance(
                payload.get("platforms"), list):
            raise _SchemaViolation('expected {"platforms": [...]}')
        items = payload["platforms"]
        if len(items) != len(platforms):
            raise _SchemaViolation("platform count mismatch")
        out: list[dict] = []
        seen: set[str] = set()
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                raise _SchemaViolation(f"platforms[{i}]: expected object")
            name = item.get("platform")
            if name != platforms[i] or name in seen:
                raise _SchemaViolation(
                    f"platforms[{i}]: expected {platforms[i]!r} once")
            seen.add(name)
            fmts = item.get("formats")
            if not isinstance(fmts, dict):
                raise _SchemaViolation(f"platforms[{i}].formats: expected object")
            vs = fmts.get("video_script")
            if not isinstance(vs, dict):
                raise _SchemaViolation("video_script: expected object")
            formats = {
                "video_script": {
                    "hook": _jstr(vs.get("hook"), "video_script.hook",
                                  max_len=300),
                    "beats": _jlist(vs.get("beats"), "video_script.beats",
                                    min_items=1, max_items=6, item_max=400),
                    "cta": _jstr(vs.get("cta"), "video_script.cta",
                                 max_len=600),
                },
                "carousel": {
                    "slides": _jlist(fmts.get("carousel", {}).get("slides"),
                                     "carousel.slides", min_items=2,
                                     max_items=8, item_max=400),
                },
                "thread": {
                    "posts": _jlist(fmts.get("thread", {}).get("posts"),
                                    "thread.posts", min_items=2,
                                    max_items=6, item_max=700),
                },
                "story_caption": _jstr(fmts.get("story_caption"),
                                      "story_caption", max_len=800),
            }
            out.append({"platform": name, "formats": formats})
        # Product-wide honesty guardrail over every AI string.
        texts: list[str] = []
        for p in out:
            f = p["formats"]
            texts += [f["video_script"]["hook"], f["video_script"]["cta"]]
            texts += f["video_script"]["beats"] + f["carousel"]["slides"]
            texts += f["thread"]["posts"] + [f["story_caption"]]
        if any(not honesty_check(t) for t in texts):
            return None
        return out
    except _SchemaViolation:
        return None


async def _ai_transform(source_text: str, url: str | None,
                        platforms: list[str]) -> list[dict] | None:
    """Ask the configured AI provider. Returns None on ANY failure so the
    caller falls back to deterministic heuristic templates. Never raises."""
    try:
        payload = await growth_ai._complete_json(
            "growth_transform", _SYSTEM_TRANSFORM,
            _transform_user_prompt(source_text, url, platforms), None)
        return _validate_transform_payload(payload, platforms)
    except (AIProviderNotConfigured, AIProviderError, ValueError,
            AttributeError, TypeError, KeyError):
        return None


# ------------------------------------------------------------------ endpoint
@router.post("/transform")
async def transform(body: TransformIn,
                    user: User = Depends(get_current_user)) -> dict:
    """Link/text -> native content drafts per platform. Drafts only."""
    url = (body.url or "").strip() or None
    text = (body.text or "").strip() or None

    title = ""
    sentences: list[str] = []
    if url:
        parsed = urlparse(url)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            raise HTTPException(
                422, "That doesn't look like a valid public link. "
                     "Paste a full http(s) URL.")
        host = parsed.netloc
        domain = _domain(host)
        try:
            # SSRF-safe fetch only — never raw sockets/requests.
            res = await fetcher.fetch_post(url, _platform_from_host(host))
        except Exception:
            raise HTTPException(
                422, "We couldn't reach that page right now. "
                     "Check the link and try again.")
        if res.level == "minimal" and not res.title and not res.description:
            raise HTTPException(
                422, "No readable preview is available for that link. "
                     "Nothing was fabricated — try the original page instead.")
        title = res.title.strip() or domain
        sentences = _sentences(res.description or "")
        source_text = f"{title}\n{(res.description or '').strip()}".strip()
    else:
        assert text is not None
        title = _clip(_sentences(text)[0] if _sentences(text) else text, 80)
        sentences = _sentences(text)
        source_text = text

    ai_platforms = await _ai_transform(source_text, url, body.platforms)
    source = "ai"
    platforms_out: list[dict] = []
    if ai_platforms is not None:
        # Guarantee: with a URL input the link appears in every CTA.
        for p in ai_platforms:
            fmts = p["formats"]
            if url:
                cta = fmts["video_script"]["cta"]
                if url not in cta:
                    fmts["video_script"]["cta"] = f"{cta.rstrip()} {url}"
                slides = fmts["carousel"]["slides"]
                if url not in slides[-1]:
                    slides[-1] = f"{slides[-1].rstrip()} {url}"
                posts = fmts["thread"]["posts"]
                if url not in posts[-1]:
                    posts[-1] = f"{posts[-1].rstrip()} {url}"
                cap = fmts["story_caption"]
                if url not in cap:
                    fmts["story_caption"] = f"{cap.rstrip()} {url}"
            platforms_out.append(p)
    else:
        source = "heuristic"
        for plat in body.platforms:
            platforms_out.append({
                "platform": plat,
                "formats": _heuristic_formats(plat, title, sentences, url),
            })

    return {
        "source": source,  # "ai" | "heuristic" — always labeled
        "title": title,
        "original_url": url or "",
        "platforms": platforms_out,
        "note": NOTE,
    }
