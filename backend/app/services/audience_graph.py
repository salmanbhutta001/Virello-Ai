"""Build the hierarchical audience-segment graph from connector signals.

Segments are interest COHORTS, never identity lists. They combine:
- aggregate connector signals (InterestSignal from audience_sources), and
- user-declared opt-in interests (existing system).

Each segment records its ``source_breakdown`` ([{source, contribution}])
and an aggregate ``confidence`` so every definition is explainable.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ads import AudienceSegment
from app.services import audience_intelligence as ai_svc
from app.services.audience_fingerprint import build_segment_path
from app.services.audience_sources.base import InterestSignal


def _contribution_weights(signals: list[InterestSignal]) -> dict[str, float]:
    """Weight each source by its connector confidence (normalized)."""
    from app.services.audience_sources.registry import get_connector
    weights: dict[str, float] = {}
    for s in signals:
        c = get_connector(s.source.split(":")[0])
        conf = c.metadata.confidence_score if c else 0.5
        weights[s.source] = weights.get(s.source, 0.0) + conf
    total = sum(weights.values()) or 1.0
    return {k: round(v / total, 3) for k, v in weights.items()}


async def upsert_segment_from_signals(
    db: AsyncSession,
    path_parts: list[str],
    signals: list[InterestSignal],
    topics: list[str],
    languages: list[str],
    geography: str = "",
    description: str = "",
) -> AudienceSegment:
    """Create or refresh one hierarchical segment from aggregate signals."""
    path = build_segment_path(*path_parts)
    weights = _contribution_weights(signals)
    breakdown = [{"source": src, "contribution": w}
                 for src, w in sorted(weights.items(),
                                      key=lambda kv: kv[1], reverse=True)]
    confidence = round(sum(
        w * _source_conf(src) for src, w in weights.items()), 3)

    existing = (await db.execute(
        select(AudienceSegment).where(AudienceSegment.path == path)
    )).scalar_one_or_none()

    rule = {"topics": topics, "languages": languages,
            "keywords": sorted({k for s in signals for k in s.keywords})[:30]}
    problems = ai_svc.validate_rule(
        {k: v for k, v in rule.items() if k in ai_svc.ALLOWED_RULE_KEYS})
    if problems:
        raise ValueError(f"Invalid segment rule: {problems}")

    sig_sources = sorted({s.source.split(":")[0] for s in signals})
    signals_used = ["opt_in_topics", "taxonomy"] + [
        f"source:{s}" for s in sig_sources]

    if existing is None:
        seg = AudienceSegment(
            name=path_parts[-1] if path_parts else path,
            description=description or f"Audience cohort: {path}",
            rule=rule, signals_used=signals_used,
            topics=topics, languages=languages,
            path=path, geography=geography.upper(),
            source_breakdown=breakdown, confidence=confidence,
            created_by="system",
            explanation=(
                f"Built from {len(signals)} aggregate signals across "
                f"{len(breakdown)} sources: "
                + ", ".join(f"{b['source']} ({b['contribution']:.0%})"
                            for b in breakdown[:4])
                + ". Interest cohort only — no personal data."),

        )
        seg.size_estimate = await ai_svc.estimate_segment_size(
            db, topics, languages)
        db.add(seg)
    else:
        existing.rule = rule
        existing.signals_used = signals_used
        existing.topics = topics
        existing.languages = languages
        existing.geography = geography.upper()
        existing.source_breakdown = breakdown
        existing.confidence = confidence
        existing.size_estimate = await ai_svc.estimate_segment_size(
            db, topics, languages)
        seg = existing
    await db.flush()
    return seg


def _source_conf(source: str) -> float:
    from app.services.audience_sources.registry import get_connector
    c = get_connector(source.split(":")[0])
    return c.metadata.confidence_score if c else 0.5


async def seed_default_graph(db: AsyncSession) -> int:
    """Seed a starter hierarchical segment graph (no live fetch required).

    Uses curated taxonomy paths; source_breakdown starts as taxonomy-only
    and is enriched whenever connectors fetch real signals.
    """
    starters = [
        (["Home & Kitchen", "Kitchen Towels", "Cooking Enthusiasts",
          "Pakistan"], ["food", "lifestyle"], ["ur", "en"], "PK"),
        (["Gaming", "Mobile Games", "Android Players", "18+"],
         ["gaming", "technology"], ["en", "ur"], ""),
        (["Beauty", "Skincare", "Product Researchers"],
         ["beauty", "health"], ["en", "ur"], ""),
        (["Technology", "AI Tools", "Early Adopters"],
         ["technology"], ["en"], ""),
        (["Finance", "Investing", "Market Watchers", "Pakistan"],
         ["finance", "business"], ["en", "ur"], "PK"),
    ]
    added = 0
    for parts, topics, langs, geo in starters:
        path = build_segment_path(*parts)
        exists = (await db.execute(
            select(AudienceSegment).where(AudienceSegment.path == path)
        )).scalar_one_or_none()
        if not exists:
            seg = AudienceSegment(
                name=parts[-2] if len(parts) > 1 else parts[0],
                description=f"Audience cohort: {path}",
                rule={"topics": topics, "languages": langs},
                signals_used=["opt_in_topics", "taxonomy"],
                topics=topics, languages=langs,
                path=path, geography=geo,
                source_breakdown=[{"source": "taxonomy", "contribution": 1.0}],
                confidence=0.5, created_by="system",
                explanation=("Starter segment from the app taxonomy. "
                             "Enriched by connector signals when available."))
            seg.size_estimate = await ai_svc.estimate_segment_size(
                db, topics, langs)
            db.add(seg)
            added += 1
    if added:
        await db.flush()
    return added
