"""Audience fingerprinting + explainable v2 segment matching.

Fingerprint: for any post/link (text or fetched content), produce
{topics[], keywords[], language, category, entities[]} using the app's own
analysis pipeline + the 24-topic taxonomy. No external profiling.

Explainable v2 scoring (weights sum to 1.0) — extends the Phase-1 v1
weights (0.45/0.20/0.15/0.10/0.10) with geography and source-confidence
factors now that the multi-source graph provides them:

    score = 0.35 * topic_overlap
          + 0.15 * keyword_overlap
          + 0.15 * language_fit
          + 0.15 * geography_match
          + 0.10 * source_confidence
          + 0.10 * content_quality

Every match returns per-factor contributions that sum to the total, plus
human-readable reasons. v1 (audience_matching.score_segment) is untouched —
existing callers keep working.

Honesty: scores are relevance fits, never reach/virality guarantees.
"""
from __future__ import annotations

import re
from hashlib import sha256

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ads import AudienceSegment
from app.services.analysis.extract import (
    analyze_language_full, detect_language, extract_hashtags,
)
from app.services.discovery.topics_seed import TOPICS
from app.services.language import get_pack
from app.services.language.semantics import TOPIC_KEYWORD_HINTS

# Urdu keyword additions merged over the shared English hints.
_TOPIC_HINTS_UR: dict[str, list[str]] = {
    "fashion": ["فیشن", "لباس"],
    "food": ["کھانا", "کھانے", "ترکیب", "پکوان"],
    "travel": ["سفر", "سیاحت"],
    "beauty": ["خوبصورتی", "میک اپ"],
}

# Keyword hints mapping free text to taxonomy topics.
_TOPIC_HINTS: dict[str, list[str]] = {
    slug: list(hints) + _TOPIC_HINTS_UR.get(slug, [])
    for slug, hints in TOPIC_KEYWORD_HINTS.items()
}

_WORD = re.compile(r"[a-z]{3,24}")
_STOP = {"the", "and", "for", "with", "from", "this", "that", "have",
         "will", "your", "you", "are", "was", "were", "has", "had",
         "not", "but", "all", "can", "just", "more", "very", "about"}

WEIGHTS_V2 = {
    "topic_overlap": 0.35,
    "keyword_overlap": 0.15,
    "language_fit": 0.15,
    "geography_match": 0.15,
    "source_confidence": 0.10,
    "content_quality": 0.10,
}

MATCH_THRESHOLD = 0.25

FINGERPRINT_DISCLAIMER = (
    "Relevance fit — not a reach, virality, or conversion guarantee. "
    "Segments are interest cohorts from public aggregate signals and "
    "opt-in data; no personal data is used.")


def _map_topics(text: str) -> list[str]:
    # Word-boundary matching (not substring): "car" must not match "skincare".
    low = f" {text.lower()} "
    hits: list[str] = []
    for slug, hints in _TOPIC_HINTS.items():
        terms = [slug] + hints
        if any(re.search(rf"(?<![a-z]){re.escape(t)}(?![a-z])", low)
               for t in terms):
            hits.append(slug)
    return hits[:6]


def _extract_keywords(text: str, limit: int = 20) -> list[str]:
    words = [w for w in _WORD.findall(text.lower()) if w not in _STOP]
    seen: list[str] = []
    for w in words:
        if w not in seen:
            seen.append(w)
        if len(seen) >= limit:
            break
    return seen


def _extract_entities(text: str, limit: int = 10) -> list[str]:
    # Simple capitalized-phrase heuristic (transparent, documented).
    found: list[str] = []
    for m in re.finditer(r"\b([A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,}){0,2})", text or ""):
        e = m.group(1).strip()
        if e.lower() not in _STOP and e not in found:
            found.append(e)
        if len(found) >= limit:
            break
    return found


def fingerprint_content(text: str = "", title: str = "",
                        url: str = "") -> dict:
    """Build an audience fingerprint from content text (deterministic)."""
    blob = f"{title}\n{text}".strip()
    hashtags = extract_hashtags(blob)
    lang_full = analyze_language_full(blob)
    language = lang_full["primary"]
    # Concept slugs found in ANY language — cross-language topic matching
    # goes through these shared IDs, never word-for-word translation.
    topics = _map_topics(blob)
    for slug in lang_full.get("concepts", []):
        if slug not in topics:
            topics.append(slug)
    topics = topics[:8]
    keywords = _extract_keywords(blob)
    entities = _extract_entities(blob)
    category = topics[0] if topics else "general"
    fp_hash = sha256(blob.encode()[:4000]).hexdigest()[:16]
    languages = [language]
    if lang_full.get("is_mixed_language"):
        for alt in lang_full.get("alternatives", []):
            if alt["code"] not in languages:
                languages.append(alt["code"])
    return {
        "topics": topics,
        "keywords": keywords,
        "hashtags": hashtags,
        "language": language,
        "languages": languages,
        "language_metadata": lang_full,
        "concepts": lang_full.get("concepts", []),
        "category": category,
        "entities": entities,
        "fingerprint_hash": fp_hash,
        "url": url,
        "disclaimer": FINGERPRINT_DISCLAIMER,
    }


def _overlap(a: list[str], b: list[str]) -> float:
    if not b:
        return 0.5  # segment has no criteria → neutral
    if not a:
        return 0.0
    return len([x for x in a if x in b]) / len(a)


def score_segment_v2(fingerprint: dict, segment: AudienceSegment) -> dict:
    """Explainable v2 score; contributions sum to total."""
    rule = segment.rule or {}
    seg_geo = (segment.geography or "").upper() if hasattr(
        segment, "geography") else ""
    fp_geo = (fingerprint.get("geography") or "").upper()
    conf = float(getattr(segment, "confidence", 0.5) or 0.5)

    seg_topics = list(segment.topics or [])
    for s in getattr(segment, "concept_slugs", None) or []:
        if s not in seg_topics:
            seg_topics.append(s)
    t = _overlap(fingerprint.get("topics", []), seg_topics)
    # keyword_overlap vs segment keywords; neutral when segment has none
    seg_kws = list(rule.get("keywords") or [])
    k = _overlap(fingerprint.get("keywords", []), seg_kws) if seg_kws else 0.5

    lang = str(fingerprint.get("language") or "unknown")
    content_langs = [str(c) for c in
                     (fingerprint.get("languages") or [lang]) if c]
    uncertain = bool((fingerprint.get("language_metadata") or {})
                     .get("detection_uncertain", False))
    seg_langs = list(segment.languages or [])
    seg_coverage = list(getattr(segment, "language_coverage", None) or [])
    seg_langs_all = seg_langs + [c for c in seg_coverage
                                 if c not in seg_langs]
    if not seg_langs_all:
        l, l_reason = 0.6, "Segment has no language criteria — neutral"
    elif any(c in seg_langs_all for c in content_langs):
        hit = next(c for c in content_langs if c in seg_langs_all)
        l, l_reason = 1.0, f"Language ({hit}) matches segment audience"
    elif lang == "unknown" or uncertain:
        l, l_reason = 0.5, ("Content language uncertain — neutral, "
                            "not assumed")
    else:
        # Partial credit: linguistically/culturally related languages
        # (e.g. Urdu content vs a Hindi-covering segment) — explainable,
        # never a full match.
        related_hit = None
        for c in content_langs:
            pack = get_pack(c)
            rel_codes = {r.code for r in pack.related()} if pack else set()
            for s in seg_langs_all:
                if s in rel_codes:
                    related_hit = (c, s)
                    break
            if related_hit:
                break
        if related_hit:
            l = 0.7
            l_reason = (f"Language {related_hit[0]} related to segment "
                        f"language {related_hit[1]} — partial fit")
        else:
            l, l_reason = 0.0, "Language does not match segment"

    if not seg_geo:
        g, g_reason = 0.6, "Segment has no geography focus — neutral"
    elif fp_geo and fp_geo == seg_geo:
        g, g_reason = 1.0, f"Geography ({seg_geo}) matches"
    elif not fp_geo:
        g, g_reason = 0.5, "Content geography unknown — neutral"
    else:
        g, g_reason = 0.0, f"Geography {fp_geo} outside segment focus {seg_geo}"

    q = max(0.0, min(100.0, float(fingerprint.get("analysis_score") or 50))) / 100.0

    factors = [
        ("topic_overlap", t,
         f"Topic overlap {t:.0%}" if t else "No topic overlap"),
        ("keyword_overlap", k,
         f"Keyword overlap {k:.0%}" if k else "No keyword overlap"),
        ("language_fit", l, l_reason),
        ("geography_match", g, g_reason),
        ("source_confidence", conf,
         f"Segment source confidence {conf:.0%}"),
        ("content_quality", q,
         "Content packaging score (heuristic, not a reach prediction)"),
    ]
    contributions = []
    reasons: list[str] = []
    total = 0.0
    for factor, fscore, reason in factors:
        weight = WEIGHTS_V2[factor]
        contrib = round(fscore * weight, 4)
        total += contrib
        contributions.append({
            "factor": factor, "weight": weight,
            "score": round(fscore, 3), "contribution": contrib,
            "reason": reason,
        })
        if reason and fscore >= 0.5:
            reasons.append(reason)
    return {
        "segment_id": str(segment.id),
        "name": segment.name,
        "path": getattr(segment, "path", "") or segment.name,
        "score": round(total, 3),
        "contributions": contributions,
        "reasons": reasons,
        "signals_used": list(segment.signals_used or []),
        "disclaimer": FINGERPRINT_DISCLAIMER,
    }


async def match_segments_v2(db: AsyncSession, fingerprint: dict,
                            threshold: float = MATCH_THRESHOLD,
                            limit: int = 10) -> list[dict]:
    segs = (await db.execute(
        select(AudienceSegment).where(AudienceSegment.is_active == True)  # noqa: E712
    )).scalars().all()
    ranked = [score_segment_v2(fingerprint, s) for s in segs]
    ranked.sort(key=lambda r: r["score"], reverse=True)
    return [r for r in ranked if r["score"] >= threshold][:limit]


def build_segment_path(*parts: str) -> str:
    """'Home & Kitchen > Kitchen Towels > Cooking Enthusiasts > Pakistan'."""
    return " > ".join(p.strip() for p in parts if p and p.strip())
