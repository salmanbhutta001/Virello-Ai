"""AI-provider-backed proposals for the Phase 1 ad platform.

Mirrors app.services.growth_ai's contract exactly:
  - Every public function returns ``dict | None`` and NEVER raises.
  - None is returned on ANY failure (provider not configured, provider
    error, malformed JSON, schema violation) — the caller falls back to
    deterministic heuristic proposals.
  - With the default "dev" provider, the strict JSON schema below is never
    satisfied, so the platform always falls back to heuristics. Intended.

Honesty rules are embedded in every prompt: no fake engagement, no bots,
no guaranteed reach/virality/followers/leads/sales — proposals and
estimates only, always labeled as such.
"""
from __future__ import annotations

import json
from typing import Any

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
    "2. Never guarantee reach, virality, followers, leads, or sales. Your "
    "output is proposals and estimates only — label nothing as a promise.\n"
    "3. Respond with ONLY a single JSON object matching the schema below. "
    "No prose, no markdown fences, no commentary.\n"
    "4. Segments and estimates must be grounded in real interest overlap "
    "(topics, language, content category) — never demographic tricks, and "
    "never infer private attributes about users.\n"
    "5. Suggested budgets must stay within the advertiser's stated budget "
    "cap when one is given."
)

_SYSTEM_BUILDER = (
    "You are the Campaign Builder agent of Virello, a legitimate AI "
    "advertising assistant. You read an advertiser's post or link and propose "
    "a campaign: objective, topics, languages, audience segments from the "
    "provided segment catalog, a recommended budget and duration. The "
    "advertiser must explicitly approve before anything launches.\n"
    + _HONESTY_RULES
)

_CAMPAIGN_SCHEMA_HINT = """\
{"objective": "views | engagement | followers | leads | sales",
 "topics": ["string, each a topic slug, max 8"],
 "languages": ["string language code, e.g. 'en', max 4"],
 "segment_ids": ["string, ids chosen from the provided catalog, max 5"],
 "recommended_budget_usd": 50.0,
 "duration_days": 7,
 "rationale": "string, why this proposal fits the content (max 500 chars)"}
Constraints: "recommended_budget_usd" between 5 and 10000;
"duration_days" between 1 and 90; only use segment ids from the catalog;
leave "segment_ids" empty only when no catalog segment matches."""


# ------------------------------------------------------------------ meta
def ai_source_meta(provider: AIProvider | None = None) -> dict:
    """Tag info for AdDecision.details describing the AI source used.

    ``dev`` is True only when the development/prototyping provider answered.
    """
    p = provider or get_ai_provider()
    return {
        "ai_provider": getattr(p, "name", "unknown"),
        "ai_model": getattr(p, "model", "") or "",
        "dev": getattr(p, "name", "") == "dev",
    }


# ------------------------------------------------------------------ validation
class _SchemaViolation(ValueError):
    """Parsed JSON failed the strict ad-platform schema."""


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
              item_max_len: int = 64) -> list[str]:
    if not isinstance(value, list):
        raise _SchemaViolation(f"{key}: expected list, got {type(value).__name__}")
    if len(value) > max_items:
        raise _SchemaViolation(f"{key}: {len(value)} items exceeds max {max_items}")
    return [_str(item, f"{key}[{i}]", min_len=1, max_len=item_max_len)
            for i, item in enumerate(value)]


def _num(value: Any, key: str, *, lo: float, hi: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise _SchemaViolation(
            f"{key}: expected number, got {type(value).__name__}")
    num = float(value)
    if not (lo <= num <= hi):
        raise _SchemaViolation(f"{key}: {num} outside {lo}..{hi}")
    return num


def _strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else ""
        if text.rstrip().endswith("```"):
            text = text.rstrip()[: -3]
    return text.strip()


_OBJECTIVES = {"views", "engagement", "followers", "leads", "sales"}


def _validate_proposal(payload: Any,
                       catalog_ids: set[str]) -> dict:
    if not isinstance(payload, dict):
        raise _SchemaViolation("expected a JSON object")
    objective = _str(payload.get("objective"), "objective", max_len=32).lower()
    if objective not in _OBJECTIVES:
        raise _SchemaViolation(f"objective: {objective!r} not allowed")
    segment_ids = _str_list(payload.get("segment_ids", []), "segment_ids",
                            max_items=5, item_max_len=64)
    unknown = [s for s in segment_ids if s not in catalog_ids]
    if unknown:
        raise _SchemaViolation(f"segment_ids not in catalog: {unknown}")
    return {
        "objective": objective,
        "topics": _str_list(payload.get("topics", []), "topics",
                            max_items=8, item_max_len=64),
        "languages": _str_list(payload.get("languages", []), "languages",
                               max_items=4, item_max_len=10),
        "segment_ids": segment_ids,
        "recommended_budget_usd": _num(payload.get("recommended_budget_usd"),
                                       "recommended_budget_usd", lo=5, hi=10000),
        "duration_days": int(_num(payload.get("duration_days"), "duration_days",
                                  lo=1, hi=90)),
        "rationale": _str(payload.get("rationale", ""), "rationale",
                          min_len=0, max_len=500),
    }


# ------------------------------------------------------------------ public API
async def _complete_json(agent: str, system: str, user: str,
                         provider: AIProvider | None) -> Any:
    p = provider or get_ai_provider()
    resp = await p.complete(AIRequest(
        agent=agent, system=system, user=user,
        max_tokens=1200, temperature=0.4, json_mode=True,
        metadata={"ads_platform": True},
    ))
    try:
        return json.loads(_strip_fences(resp.text or ""))
    except (json.JSONDecodeError, ValueError) as exc:
        raise ValueError(f"provider returned non-JSON text: {exc}") from exc


async def propose_campaign_via_ai(
    content_summary: str,
    catalog: list[dict],
    budget_cap: float | None = None,
    provider: AIProvider | None = None,
) -> dict | None:
    """Ask the AI provider for a campaign proposal as strict JSON.

    ``catalog`` is a list of {"id", "name", "topics", "languages",
    "description"} segment dicts; the model may only pick ids from it.
    Returns the validated proposal dict, or None on ANY failure so the
    caller falls back to heuristic proposals. Never raises.
    """
    catalog_ids = {str(s.get("id")) for s in catalog}
    catalog_txt = "\n".join(
        f"- {s.get('id')}: {s.get('name')} "
        f"(topics={','.join(s.get('topics') or [])}; "
        f"languages={','.join(s.get('languages') or [])}) — "
        f"{(s.get('description') or '')[:120]}"
        for s in catalog[:20])
    cap_txt = (f"\nAdvertiser budget cap: USD {budget_cap:.2f}. "
               "Your recommended budget MUST NOT exceed it."
               if budget_cap and budget_cap > 0 else "")
    user_prompt = (
        f"Content summary:\n{content_summary[:1500]}\n\n"
        f"Audience segment catalog (pick ids from here only):\n"
        f"{catalog_txt or '(catalog is empty — return an empty segment_ids list)'}\n"
        f"{cap_txt}\n\n"
        "Propose a campaign for this content. Estimates are suggestions "
        "only — never phrase anything as guaranteed.\n"
        f"Schema:\n{_CAMPAIGN_SCHEMA_HINT}"
    )
    try:
        payload = await _complete_json(
            "ads_builder", _SYSTEM_BUILDER, user_prompt, provider)
        return _validate_proposal(payload, catalog_ids)
    except (AIProviderNotConfigured, AIProviderError, ValueError,
            AttributeError, TypeError, KeyError):
        return None

# ------------------------------------------------------------------ optimizer proposals
_SYSTEM_OPTIMIZER = (
    "You are the Distribution & Optimization agent of Virello, a legitimate "
    "AI advertising assistant. You read measured campaign performance "
    "(genuine events only — impressions, views, engagements) and suggest "
    "small, bounded distribution adjustments: shift weight toward "
    "better-performing audience segments, reduce or pause underperformers, "
    "and propose one fresh creative variant when the current one stagnates.\n"
    + _HONESTY_RULES
    + "\n6. You never change budgets, never raise spend, and never guarantee "
    "outcomes. Weight multipliers must stay inside 0.5..1.5; only flag a "
    "segment for pause when it clearly underperforms on a large sample.\n"
    "7. Base every suggestion on the supplied measured metrics — invent no "
    "numbers."
)

_OPTIMIZE_SCHEMA_HINT = """\
{"segment_actions": [
   {"segment_id": "string, must be an id from the catalog below",
    "action": "up | down | pause | keep",
    "multiplier": 1.0,
    "note": "string, plain-language reason, max 200 chars"}],
 "placement_actions": [
   {"placement_id": "string, must be an id from the catalog below",
    "action": "up | down | pause | keep",
    "multiplier": 1.0,
    "note": "string, plain-language reason, max 200 chars"}],
 "new_variant": {"label": "string, max 80 chars",
                 "hook": "string, max 140 chars",
                 "caption": "string, max 280 chars",
                 "hashtags": ["string, max 5"],
                 "rationale": "string, max 300 chars"} or null,
 "rationale": "string, overall reasoning, max 500 chars"}
Constraints: "action" one of up|down|pause|keep; "multiplier" 0.5..1.5 and
must be 1.0 when action is keep or pause; only ids from the catalogs;
"new_variant" null when no new variant is needed."""


def _validate_optimize_action(payload: Any, key: str,
                              allowed_ids: set[str]) -> list[dict]:
    items = payload.get(key) or []
    if not isinstance(items, list):
        raise _SchemaViolation(f"{key}: expected list")
    if len(items) > 10:
        raise _SchemaViolation(f"{key}: too many items")
    actions = ("up", "down", "pause", "keep")
    out = []
    for i, a in enumerate(items):
        if not isinstance(a, dict):
            raise _SchemaViolation(f"{key}[{i}]: expected object")
        sid = _str(a.get("segment_id" if key == "segment_actions"
                         else "placement_id"),
                   f"{key}[{i}].id", max_len=64)
        if sid not in allowed_ids:
            raise _SchemaViolation(f"{key}[{i}]: id not in catalog")
        act = _str(a.get("action"), f"{key}[{i}].action",
                   max_len=8).lower()
        if act not in actions:
            raise _SchemaViolation(f"{key}[{i}]: bad action {act!r}")
        mult = _num(a.get("multiplier", 1.0),
                    f"{key}[{i}].multiplier", lo=0.5, hi=1.5)
        if act in ("keep", "pause") and mult != 1.0:
            raise _SchemaViolation(f"{key}[{i}]: multiplier must be 1.0 "
                                   "for keep/pause")
        out.append({
            "id": sid, "action": act, "multiplier": mult,
            "note": _str(a.get("note", ""), f"{key}[{i}].note",
                         min_len=0, max_len=200),
        })
    return out


def _validate_new_variant(payload: Any) -> dict | None:
    v = payload.get("new_variant")
    if v is None:
        return None
    if not isinstance(v, dict):
        raise _SchemaViolation("new_variant: expected object or null")
    return {
        "label": _str(v.get("label"), "new_variant.label", max_len=80),
        "hook": _str(v.get("hook"), "new_variant.hook", max_len=140),
        "caption": _str(v.get("caption"), "new_variant.caption", max_len=280),
        "hashtags": _str_list(v.get("hashtags", []), "new_variant.hashtags",
                              max_items=5, item_max_len=32),
        "rationale": _str(v.get("rationale", ""), "new_variant.rationale",
                          min_len=0, max_len=300),
    }


def _validate_optimize_proposal(payload: Any, segment_ids: set[str],
                                placement_ids: set[str]) -> dict:
    if not isinstance(payload, dict):
        raise _SchemaViolation("expected a JSON object")
    return {
        "segment_actions": _validate_optimize_action(
            payload, "segment_actions", segment_ids),
        "placement_actions": _validate_optimize_action(
            payload, "placement_actions", placement_ids),
        "new_variant": _validate_new_variant(payload),
        "rationale": _str(payload.get("rationale", ""), "rationale",
                          min_len=0, max_len=500),
    }


async def propose_optimization_via_ai(
    campaign_summary: str,
    segment_catalog: list[dict],
    placement_catalog: list[dict],
    provider: AIProvider | None = None,
) -> dict | None:
    """Ask the AI provider for bounded distribution adjustments as strict
    JSON. Catalogs are lists of {"id", "name", "impressions", "views",
    "engagement_rate"} dicts. Returns the validated proposal dict, or None
    on ANY failure so the caller falls back to heuristic rules. Never raises.
    """
    segment_ids = {str(s.get("id")) for s in segment_catalog}
    placement_ids = {str(p.get("id")) for p in placement_catalog}

    def _rows(catalog: list[dict]) -> str:
        lines = []
        for s in catalog[:10]:
            lines.append(
                f"- {s.get('id')}: {s.get('name')} "
                f"(impressions={s.get('impressions', 0)}, "
                f"views={s.get('views', 0)}, "
                f"engagement_rate={s.get('engagement_rate', 0)})")
        return "\n".join(lines) or "(none)"

    user_prompt = (
        f"Campaign performance (genuine measured events only):\n"
        f"{campaign_summary[:1200]}\n\n"
        f"Segments:\n{_rows(segment_catalog)}\n\n"
        f"Placements:\n{_rows(placement_catalog)}\n\n"
        "Suggest bounded distribution adjustments. These are estimates and "
        "guidance only — never phrase anything as guaranteed.\n"
        f"Schema:\n{_OPTIMIZE_SCHEMA_HINT}"
    )
    try:
        payload = await _complete_json(
            "ads_optimizer", _SYSTEM_OPTIMIZER, user_prompt, provider)
        return _validate_optimize_proposal(payload, segment_ids,
                                           placement_ids)
    except (AIProviderNotConfigured, AIProviderError, ValueError,
            AttributeError, TypeError, KeyError):
        return None
