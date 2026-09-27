"""AI-provider-backed proposals for the Growth Engine's audience/content agents.

The provider layer is modular (app.services.ai.base): the real provider is
chosen via VIRELLO_AI_PROVIDER (dev | anthropic | openai | google); the
default "dev" provider is for prototyping only.

Contract with the caller (growth_engine):
  - Both public functions return ``list[dict] | None`` and NEVER raise.
  - They return None on ANY failure: provider not configured, provider error,
    malformed JSON, or schema violation — the caller then falls back to the
    deterministic heuristic/template proposals.
  - The "dev" provider's generic template can never satisfy the strict JSON
    schema below, so with no production provider configured the engine always
    falls back to heuristics. That is the intended, expected behavior.

Honesty rules are embedded in every prompt: no fake engagement, no bots, no
guaranteed virality/reach/sales — suggestions and estimates only.
"""
from __future__ import annotations

import json
from typing import Any

from app.models.core import Campaign
from app.models.growth import PostAnalysis
from app.services.ai.base import (
    AIProvider,
    AIProviderError,
    AIProviderNotConfigured,
    AIRequest,
    get_ai_provider,
)

# ------------------------------------------------------------------ honesty
_HONESTY_RULES = (
    "STRICT HONESTY RULES (violate none of these):\n"
    "1. Never suggest fake engagement, bots, click farms, traffic exchanges, "
    "or artificial accounts.\n"
    "2. Never guarantee virality, reach, followers, leads, or sales. Your "
    "output is suggestions and estimates only — label nothing as a promise.\n"
    "3. Respond with ONLY a single JSON object matching the schema below. "
    "No prose, no markdown fences, no commentary.\n"
    "4. Suggestions must be plausible, non-manipulative, and respectful of "
    "real users."
)

_SYSTEM_AUDIENCE = (
    "You are the Audience Agent of Virello, an AI growth manager. You identify "
    "audience segments that are genuinely likely to be interested in a "
    "creator's post, for distribution inside Virello's own opt-in Discovery "
    "Platform (users voluntarily follow topics; creators opt in to placement).\n"
    + _HONESTY_RULES
)

_SYSTEM_CONTENT = (
    "You are the Content Agent of Virello, an AI growth manager. You propose "
    "content variations (hooks, captions, hashtags, thumbnail briefs, posting "
    "windows) for a creator's post. The creator's original version is always "
    "kept as the baseline and every suggestion is measured against it.\n"
    + _HONESTY_RULES
)

_ORIGINAL_LABEL = "Original (creator's version)"

_AUDIENCE_SCHEMA_HINT = """\
{"segments": [
  {"name": "string (segment name, max 120 chars)",
   "topics": ["string, each max 40 chars, max 8 topics"],
   "markets": "string, e.g. 'USA, UK' (max 60 chars)",
   "language": "string language code, e.g. 'en' (max 10 chars)",
   "boost": 1.0,
   "reason": "string, why this segment fits (max 300 chars)"}
]}
Constraints: 1-4 segments. "boost" is a distribution multiplier between 0.5 and 2.0."""

_VARIANTS_SCHEMA_HINT = """\
{"variants": [
  {"label": "string (variant name, max 120 chars)",
   "title": "string (display title, max 200 chars)",
   "caption": "string (full caption text, max 2000 chars)",
   "hashtags": ["string, max 40 chars each, max 12 hashtags"],
   "thumbnail_brief": "string (thumbnail guidance, max 500 chars)",
   "posting_window": "string, e.g. '12:00-14:00' (max 60 chars)",
   "rationale": "string, why this variation may help (max 500 chars)"}
]}
Constraints: EXACTLY 4 variants. Variant 1 MUST be the faithful original: label exactly
"Original (creator's version)", title/caption equal to the post title as given.
The other 3 are honest hook/caption variations of the SAME post — never invent new
claims about the post."""


# ------------------------------------------------------------------ meta
def ai_source_meta(provider: AIProvider | None = None) -> dict:
    """Tag info for GrowthDecision.details describing the AI source used.

    ``dev`` is True only when the development/prototyping provider answered.
    """
    p = provider or get_ai_provider()
    return {
        "ai_provider": getattr(p, "name", "unknown"),
        "ai_model": getattr(p, "model", "") or "",
        "dev": getattr(p, "name", "") == "dev",
    }


# ------------------------------------------------------------------ prompt
def _campaign_context(campaign: Campaign, analysis: PostAnalysis | None) -> str:
    goal = (campaign.goal.value if hasattr(campaign.goal, "value")
            else str(campaign.goal or "engagement"))
    parts = [
        f"Post title: {campaign.title or '(untitled)'}",
        f"Post URL: {campaign.post_url or ''}",
        f"Platform: {campaign.platform or 'social'}",
        f"Campaign goal: {goal}",
        f"Campaign markets: {campaign.markets or 'worldwide'}",
    ]
    if analysis is not None:
        parts.append(f"Analyzed title: {analysis.title or ''}")
        parts.append(f"Detected language: {analysis.language or 'unknown'}")
        tags = ", ".join((analysis.hashtags or [])[:10])
        parts.append(f"Hashtags found: {tags or '(none)'}")
        desc = (analysis.description or "")[:400]
        if desc:
            parts.append(f"Description excerpt: {desc}")
    return "\n".join(parts)


def _audience_user_prompt(campaign: Campaign, analysis: PostAnalysis | None,
                          topics: list[str], markets: str,
                          language: str) -> str:
    ctx = _campaign_context(campaign, analysis)
    return (
        f"{ctx}\n"
        f"Discovery placement topics: {', '.join(topics) or '(none chosen)'}\n"
        f"Target markets: {markets or 'worldwide'}\n"
        f"Post language: {language or 'unknown'}\n\n"
        "Propose the audience segments this post should be distributed to. "
        "Segments should reflect real interest overlap (topics, language, "
        "market) — not demographic tricks.\n"
        f"Schema:\n{_AUDIENCE_SCHEMA_HINT}"
    )


def _variants_user_prompt(campaign: Campaign, analysis: PostAnalysis | None,
                          goal: str) -> str:
    ctx = _campaign_context(campaign, analysis)
    return (
        f"{ctx}\n"
        f"Optimization goal: {goal}\n\n"
        "Propose content variations for this post. Keep every variant faithful "
        "to the original post — same subject, no invented claims.\n"
        f"Schema:\n{_VARIANTS_SCHEMA_HINT}"
    )


# ------------------------------------------------------------------ validation
class _SchemaViolation(ValueError):
    """Parsed JSON failed the strict Growth Engine schema."""


def _str(value: Any, key: str, *, min_len: int = 1,
         max_len: int = 500) -> str:
    if not isinstance(value, str):
        raise _SchemaViolation(f"{key}: expected string, got {type(value).__name__}")
    text = value.strip()
    if not (min_len <= len(text) <= max_len):
        raise _SchemaViolation(
            f"{key}: length {len(text)} outside {min_len}..{max_len}")
    return text


def _str_list(value: Any, key: str, *, max_items: int,
              item_max_len: int = 40) -> list[str]:
    if not isinstance(value, list):
        raise _SchemaViolation(f"{key}: expected list, got {type(value).__name__}")
    if len(value) > max_items:
        raise _SchemaViolation(f"{key}: {len(value)} items exceeds max {max_items}")
    out = []
    for i, item in enumerate(value):
        out.append(_str(item, f"{key}[{i}]", min_len=1, max_len=item_max_len))
    return out


def _num(value: Any, key: str, *, lo: float, hi: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise _SchemaViolation(
            f"{key}: expected number, got {type(value).__name__}")
    num = float(value)
    if not (lo <= num <= hi):
        raise _SchemaViolation(f"{key}: {num} outside {lo}..{hi}")
    return num


def _strip_fences(text: str) -> str:
    """Tolerate models that wrap JSON in markdown fences."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else ""
        if text.rstrip().endswith("```"):
            text = text.rstrip()[: -3]
    return text.strip()


def _validate_segments(payload: Any) -> list[dict]:
    if not isinstance(payload, dict) or not isinstance(payload.get("segments"), list):
        raise _SchemaViolation("expected {\"segments\": [...]}")
    segs = payload["segments"]
    if not (1 <= len(segs) <= 4):
        raise _SchemaViolation(f"segments: {len(segs)} outside 1..4")
    out = []
    for i, s in enumerate(segs):
        if not isinstance(s, dict):
            raise _SchemaViolation(f"segments[{i}]: expected object")
        out.append({
            "name": _str(s.get("name"), f"segments[{i}].name", max_len=120),
            "topics": _str_list(s.get("topics"), f"segments[{i}].topics",
                                max_items=8, item_max_len=40),
            "markets": _str(s.get("markets"), f"segments[{i}].markets",
                            max_len=60),
            "language": _str(s.get("language"), f"segments[{i}].language",
                             max_len=10),
            "boost": _num(s.get("boost"), f"segments[{i}].boost",
                          lo=0.5, hi=2.0),
            "reason": _str(s.get("reason"), f"segments[{i}].reason",
                           max_len=300),
        })
    return out


def _validate_variants(payload: Any) -> list[dict]:
    if not isinstance(payload, dict) or not isinstance(payload.get("variants"), list):
        raise _SchemaViolation("expected {\"variants\": [...]}")
    variants = payload["variants"]
    if not (1 <= len(variants) <= 4):
        raise _SchemaViolation(f"variants: {len(variants)} outside 1..4")
    out = []
    for i, v in enumerate(variants):
        if not isinstance(v, dict):
            raise _SchemaViolation(f"variants[{i}]: expected object")
        out.append({
            "label": _str(v.get("label"), f"variants[{i}].label", max_len=120),
            "title": _str(v.get("title"), f"variants[{i}].title", max_len=200),
            "caption": _str(v.get("caption"), f"variants[{i}].caption",
                            max_len=2000),
            "hashtags": _str_list(v.get("hashtags"), f"variants[{i}].hashtags",
                                  max_items=12, item_max_len=40),
            "thumbnail_brief": _str(v.get("thumbnail_brief"),
                                    f"variants[{i}].thumbnail_brief",
                                    max_len=500),
            "posting_window": _str(v.get("posting_window"),
                                   f"variants[{i}].posting_window",
                                   max_len=60),
            "rationale": _str(v.get("rationale"), f"variants[{i}].rationale",
                              max_len=500),
        })
    return out


# ------------------------------------------------------------------ public API
async def _complete_json(agent: str, system: str, user: str,
                         provider: AIProvider | None) -> Any:
    """Call the provider in JSON mode and parse the response.

    Raises AIProviderNotConfigured / AIProviderError / ValueError on failure.
    """
    p = provider or get_ai_provider()
    resp = await p.complete(AIRequest(
        agent=agent, system=system, user=user,
        max_tokens=1500, temperature=0.4, json_mode=True,
        metadata={"growth_engine": True},
    ))
    try:
        return json.loads(_strip_fences(resp.text or ""))
    except (json.JSONDecodeError, ValueError) as exc:
        raise ValueError(f"provider returned non-JSON text: {exc}") from exc


async def audience_segments_via_ai(
    campaign: Campaign,
    analysis: PostAnalysis | None,
    topics: list[str],
    markets: str,
    language: str,
    provider: AIProvider | None = None,
) -> list[dict] | None:
    """Ask the AI provider for audience segments as strict JSON.

    Returns the validated segment dicts, or None on ANY failure so the caller
    falls back to heuristic segments. Never raises.
    """
    try:
        payload = await _complete_json(
            "growth_audience", _SYSTEM_AUDIENCE,
            _audience_user_prompt(campaign, analysis, topics or [],
                                  markets or "worldwide",
                                  language or "unknown"),
            provider,
        )
        return _validate_segments(payload)
    except (AIProviderNotConfigured, AIProviderError, ValueError,
            AttributeError, TypeError, KeyError):
        return None


async def content_variants_via_ai(
    campaign: Campaign,
    analysis: PostAnalysis | None,
    goal: str,
    provider: AIProvider | None = None,
) -> list[dict] | None:
    """Ask the AI provider for exactly 4 content variants as strict JSON.

    Returns the validated variant dicts, or None on ANY failure so the caller
    falls back to template variants. Never raises.
    """
    try:
        payload = await _complete_json(
            "growth_content", _SYSTEM_CONTENT,
            _variants_user_prompt(campaign, analysis, goal or "engagement"),
            provider,
        )
        return _validate_variants(payload)
    except (AIProviderNotConfigured, AIProviderError, ValueError,
            AttributeError, TypeError, KeyError):
        return None
