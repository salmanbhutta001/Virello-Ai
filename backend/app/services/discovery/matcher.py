"""Explainable discovery matching.

score = 0.50 * topic_overlap
      + 0.20 * market_fit
      + 0.15 * language_fit
      + 0.10 * freshness
      + 0.05 * goal_clarity

Every served item carries human-readable reasons — the user always sees
*why* something was recommended. No black-box boosting, no paid placement.
"""
from __future__ import annotations

from datetime import datetime, timezone

WEIGHTS = {
    "topic": 0.50,
    "market": 0.20,
    "language": 0.15,
    "freshness": 0.10,
    "goal": 0.05,
}


def _topic_score(user_topics: set[str], placement_topics: list[str]) -> tuple[float, list[str]]:
    if not placement_topics:
        return 0.0, []
    overlap = [t for t in placement_topics if t in user_topics]
    score = len(overlap) / len(placement_topics)
    reasons = [f"Matches your interests: {', '.join(overlap)}"] if overlap else []
    return score, reasons


def _market_score(campaign_markets: list[str]) -> tuple[float, list[str]]:
    markets = [m.lower() for m in campaign_markets]
    if "worldwide" in markets:
        return 1.0, ["Available worldwide"]
    return 0.4, [f"Targeted at {', '.join(campaign_markets)}"]


def _language_score(campaign_language: str, user_locale: str,
                    user_languages: list[str] | None = None,
                    campaign_languages: list[str] | None = None,
                    all_relevant: bool = False,
                    language_uncertain: bool = False) -> tuple[float, list[str]]:
    """Preference-aware language fit.

    user_languages: preferred + content languages (explicit choices).
    campaign_languages: all languages detected in the content.
    all_relevant: user opted into every relevant language.
    Uncertain detection is neutral, never assumed.
    """
    from app.services.language import get_pack

    user_langs = [u for u in (user_languages or [user_locale]) if u]
    camp_langs = [c for c in (campaign_languages or [campaign_language])
                  if c and c != "unknown"]
    if not camp_langs:
        return 0.5, []
    if language_uncertain:
        return 0.5, ["Language unclear — shown anyway"]
    if all_relevant or any(c in user_langs for c in camp_langs):
        hit = next((c for c in camp_langs if c in user_langs), camp_langs[0])
        pack = get_pack(hit)
        label = pack.name_native if pack else hit
        return 1.0, [f"In your language ({label})"]
    # Partial credit for related languages (Urdu ↔ Hindi, etc.).
    for c in camp_langs:
        pack = get_pack(c)
        rel = {r.code for r in pack.related()} if pack else set()
        if rel.intersection(user_langs):
            return 0.7, ["In a related language"]
    return 0.3, []


def _freshness_score(created_at: datetime | None) -> tuple[float, list[str]]:
    if not created_at:
        return 0.5, []
    age_days = (datetime.now(timezone.utc) - created_at.replace(
        tzinfo=timezone.utc)).total_seconds() / 86400
    if age_days <= 3:
        return 1.0, ["Fresh"]
    if age_days <= 14:
        return max(0.2, 1.0 - age_days / 14), []
    return 0.2, []


def score_candidate(*, user_topics: set[str], user_locale: str,
                    placement_topics: list[str], campaign_markets: list[str],
                    campaign_language: str, campaign_created_at,
                    topic_names: dict[str, str] | None = None,
                    user_languages: list[str] | None = None,
                    campaign_languages: list[str] | None = None,
                    all_relevant_languages: bool = False,
                    language_uncertain: bool = False) -> dict:
    topic_names = topic_names or {}
    t, r1 = _topic_score(user_topics, placement_topics)
    # Localize reason topic slugs when names are available.
    if r1 and topic_names:
        pretty = [topic_names.get(slug, slug) for slug in
                  [s for s in placement_topics if s in user_topics]]
        r1 = [f"Matches your interests: {', '.join(pretty)}"]
    m, r2 = _market_score(campaign_markets)
    l, r3 = _language_score(campaign_language, user_locale,
                           user_languages=user_languages,
                           campaign_languages=campaign_languages,
                           all_relevant=all_relevant_languages,
                           language_uncertain=language_uncertain)
    f, r4 = _freshness_score(campaign_created_at)
    g = 1.0  # every campaign has an explicit goal in v1
    total = (t * WEIGHTS["topic"] + m * WEIGHTS["market"]
             + l * WEIGHTS["language"] + f * WEIGHTS["freshness"]
             + g * WEIGHTS["goal"])
    return {
        "score": round(total, 3),
        "reasons": r1 + r2 + r3 + r4,
        "components": {"topic": round(t, 3), "market": round(m, 3),
                       "language": round(l, 3), "freshness": round(f, 3),
                       "goal": g},
    }
