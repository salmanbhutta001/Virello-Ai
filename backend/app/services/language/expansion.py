"""Language-audience expansion: recommend additional language audiences.

Given the languages detected in a piece of content (and its concept IDs),
suggest other languages whose audiences are likely relevant — each with a
human-readable reason. Recommendations are explainable suggestions, never
guarantees, and never invent audience sizes.
"""
from __future__ import annotations

from .packs import get_pack


def recommend_languages(content_languages: list[str],
                        concepts: list[str] | None = None,
                        segments: list[dict] | None = None,
                        limit: int = 5) -> list[dict]:
    """Recommend additional language audiences.

    Args:
        content_languages: ISO codes detected in the content.
        concepts: canonical topic slugs found in the content.
        segments: candidate audience segments as dicts with
            ``topics`` (slugs) and ``language_coverage`` (codes).
    Returns:
        List of {code, name_en, name_native, reason, basis, score}.
    """
    content_languages = [c for c in (content_languages or []) if c]
    concepts = concepts or []
    segments = segments or []
    scored: dict[str, dict] = {}

    def add(code: str, reason: str, basis: str, points: float) -> None:
        if not code or code in content_languages:
            return
        pack = get_pack(code)
        if pack is None:
            return
        entry = scored.setdefault(code, {
            "code": code,
            "name_en": pack.name_en,
            "name_native": pack.name_native,
            "reasons": [],
            "score": 0.0,
        })
        if reason not in entry["reasons"]:
            entry["reasons"].append(reason)
        entry["score"] += points
        entry["basis"] = basis

    # 1. Related languages from packs (linguistic/cultural proximity).
    for lang in content_languages:
        pack = get_pack(lang)
        if not pack:
            continue
        for rel in pack.related():
            add(rel.code,
                f"Related to {pack.name_en}: {rel.reason}",
                "language-pack related languages", 1.0)

    # 2. Segments that match the content's concepts and cover other
    #    languages — real audience overlap, not invented.
    for seg in segments:
        seg_topics = set(seg.get("topics") or [])
        overlap = seg_topics.intersection(concepts)
        if not overlap:
            continue
        for code in seg.get("language_coverage") or []:
            add(code,
                f"Segment '{seg.get('name', '?')}' matches "
                f"{len(overlap)} shared topic(s) and covers {code}",
                "audience segment overlap", 1.5 * len(overlap))

    # 3. Concepts with strong multilingual labels: if the content's
    #    concepts have curated packs in other languages, note it.
    for lang in content_languages:
        pack = get_pack(lang)
        if pack and pack.pack_quality == "curated":
            for other in ("en", "ur", "ar", "hi", "es", "fr"):
                if other == lang:
                    continue
                op = get_pack(other)
                if op and op.pack_quality == "curated":
                    add(other,
                        f"{pack.name_en} content on these topics also "
                        f"performs with {op.name_en} audiences",
                        "curated multilingual topic coverage", 0.5)

    ranked = sorted(scored.values(), key=lambda e: e["score"], reverse=True)
    out = []
    for e in ranked[:limit]:
        out.append({
            "code": e["code"],
            "name_en": e["name_en"],
            "name_native": e["name_native"],
            "reason": "; ".join(e["reasons"][:2]),
            "basis": e.get("basis", ""),
            "score": round(e["score"], 2),
        })
    return out
