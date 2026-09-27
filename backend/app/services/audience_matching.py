"""Audience Matching Engine — rank audience segments for a piece of content.

Explainable scoring (weights sum to 1.0):
    score = 0.45 * topic_overlap
          + 0.20 * language_fit
          + 0.15 * hashtag_affinity
          + 0.10 * category_affinity
          + 0.10 * content_quality

Every match carries per-factor contributions [{factor, weight, contribution,
reason}] whose contributions sum to the total score, plus human-readable
reasons. Membership is computed at match time from opt-in data — matching
never reads or exposes any user's private data.
"""
from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ads import AudienceSegment
from app.services import audience_intelligence as ai_svc
from app.services import geo as geo_svc

WEIGHTS = {
    "topic_overlap": 0.45,
    "language_fit": 0.20,
    "hashtag_affinity": 0.15,
    "category_affinity": 0.10,
    "content_quality": 0.10,
}

DEFAULT_THRESHOLD = 0.25


def _overlap(content_items: list[str], segment_items: list[str],
             kind: str) -> tuple[float, str | None]:
    """Shared overlap factor: neutral 0.5 when the segment has no criteria."""
    if not segment_items:
        return 0.5, f"Segment has no {kind} criteria — neutral"
    if not content_items:
        return 0.0, f"Content has no {kind} signals"
    overlap = [i for i in content_items if i in segment_items]
    score = len(overlap) / len(content_items)
    if overlap:
        return score, f"{kind.title()} overlap: {', '.join(overlap[:5])}"
    return 0.0, f"No {kind} overlap with segment criteria"


def _language_fit(content_lang: str, segment_langs: list[str]
                  ) -> tuple[float, str | None]:
    if not segment_langs:
        return 0.6, "Segment has no language criteria — neutral"
    if not content_lang or content_lang == "unknown":
        return 0.5, "Content language unknown — neutral"
    if content_lang in segment_langs:
        label = {"en": "English", "ur": "Urdu", "ar": "Arabic"}.get(
            content_lang, content_lang)
        return 1.0, f"Content language ({label}) matches segment audience"
    return 0.0, f"Content language does not match segment ({'/'.join(segment_langs)})"


def _content_quality(analysis_score: float) -> tuple[float, str | None]:
    clamped = max(0.0, min(100.0, float(analysis_score or 0)))
    return clamped / 100.0, (
        f"Content packaging score {clamped:.0f}/100 from the analysis engine "
        "(transparent heuristic, not a reach prediction)")


def score_segment(signals: dict, segment: AudienceSegment) -> dict:
    """Score one segment against content signals; contributions sum to total."""
    rule = segment.rule or {}
    factors: list[tuple[str, float, str | None]] = []

    t, r = _overlap(list(signals.get("topics") or []),
                    list(segment.topics or []), "topics")
    factors.append(("topic_overlap", t, r))

    l, r = _language_fit(str(signals.get("language") or "unknown"),
                         list(segment.languages or []))
    factors.append(("language_fit", l, r))

    h, r = _overlap(list(signals.get("hashtags") or []),
                    list(rule.get("hashtags") or []), "hashtags")
    factors.append(("hashtag_affinity", h, r))

    c, r = _overlap(list(signals.get("categories") or []),
                    list(rule.get("categories") or []), "categories")
    factors.append(("category_affinity", c, r))

    q, r = _content_quality(float(signals.get("analysis_score") or 0))
    factors.append(("content_quality", q, r))

    contributions = []
    reasons: list[str] = []
    total = 0.0
    for factor, fscore, reason in factors:
        weight = WEIGHTS[factor]
        contribution = round(fscore * weight, 4)
        total += contribution
        contributions.append({
            "factor": factor, "weight": weight,
            "score": round(fscore, 3), "contribution": contribution,
            "reason": reason or "",
        })
        if reason and fscore >= 0.5:
            reasons.append(reason)

    return {
        "segment_id": str(segment.id),
        "name": segment.name,
        "score": round(total, 3),
        "contributions": contributions,
        "reasons": reasons,
        "signals_used": list(segment.signals_used or []),
    }


async def match_segments(db: AsyncSession, signals: dict,
                         segments: list[AudienceSegment] | None = None,
                         threshold: float = DEFAULT_THRESHOLD,
                         geo_countries: list[str] | None = None) -> list[dict]:
    """Rank active segments for the content; keep those >= threshold.

    ``geo_countries`` (optional): the campaign's effective country set.
    Segments whose *declared* geography lies outside the set are excluded
    (zero-overlap filter) and the exclusion is recorded explainably in each
    match's ``geography_fit``. Global segments (no declared geography) are
    always eligible. ``None`` = no geography targeting, nothing filtered.
    """
    segs = (segments if segments is not None
            else await ai_svc.list_active_segments(db))
    effective = ({str(c).upper() for c in geo_countries}
                 if geo_countries is not None else None)
    ranked = []
    for s in segs:
        fit = geography_fit(s, effective)
        m = score_segment(signals, s)
        m["geography_fit"] = fit
        if not fit["in_target"]:
            continue
        ranked.append(m)
    ranked.sort(key=lambda m: m["score"], reverse=True)
    return [m for m in ranked if m["score"] >= threshold]


def geography_fit(segment: AudienceSegment,
                  effective_countries: set[str] | None) -> dict:
    """Declared-geography fit of one segment against the effective set.

    Only the segment's *declared* ``geography`` field is consulted — never
    any per-user data, never inferred location. Returns
    {"in_target": bool, "reason": str, "segment_geography": str}.
    """
    geo = str(getattr(segment, "geography", "") or "").strip().upper()
    name = getattr(segment, "name", "segment")
    if effective_countries is None:
        return {"in_target": True,
                "reason": ("No geography targeting on this campaign — "
                           f"{name} is eligible."),
                "segment_geography": geo}
    if not geo:
        return {"in_target": True,
                "reason": (f"{name} is global (no declared geography) — "
                           "eligible in every targeted country."),
                "segment_geography": geo}
    label = geo_svc.COUNTRY_NAMES.get(geo, geo)
    if geo in effective_countries:
        return {"in_target": True,
                "reason": (f"{name} is focused on {label} — inside the "
                           "campaign's targeted countries."),
                "segment_geography": geo}
    return {"in_target": False,
            "reason": (f"{name} is focused on {label} — outside the "
                       "campaign's targeted countries, so it is excluded "
                       "from delivery (declared geography, not a guess)."),
            "segment_geography": geo}
