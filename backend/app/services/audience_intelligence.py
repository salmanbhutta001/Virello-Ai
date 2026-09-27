"""Audience Intelligence Engine — build audience segments from legitimate
signals only.

Legitimate signals (and ONLY these):
  - user-declared interests (discovery opt-ins: user_interests rows)
  - the 24-topic EN/UR taxonomy (app.services.discovery.topics_seed)
  - declared language (user.locale — a declared preference, never inferred)
  - content categories / hashtags / language derived from the ad content itself
  - aggregate/anonymized trend counts

Privacy by design:
  - Segment DEFINITIONS are stored; per-user segment MEMBERSHIP is never
    stored. Membership is computed at match time from opt-in data.
  - size_estimate is an aggregate count only — no per-user rows involved.

Size-estimate formula (documented, honest):
    size_estimate = COUNT(DISTINCT users with >=1 user_interests row whose
                          topic_slug is in the segment's topics
                          [AND user.locale in segment languages when set])

This is a coarse estimate: real reach depends on delivery, content quality,
user attention, and budget. It is labeled "estimate — not a guarantee"
everywhere it is shown.
"""
from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ads import AudienceSegment
from app.models.core import User
from app.models.growth import UserInterest
from app.services.discovery.topics_seed import TOPICS

TAXONOMY_SLUGS = {slug for slug, _, _ in TOPICS}

# Rule keys that are allowed in segment definitions. Anything else —
# especially anything that could carry private attributes — is rejected.
ALLOWED_RULE_KEYS = {"topics", "languages", "hashtags", "categories"}
FORBIDDEN_RULE_KEYS = {
    "user_id", "user_ids", "email", "emails", "name", "age", "gender",
    "location", "country", "city", "ip", "device", "phone", "address",
    "dob", "birthday", "income", "religion", "ethnicity",
}

SIZE_ESTIMATE_DISCLAIMER = (
    "Estimate — not a guarantee. Rough count of users who opted in to the "
    "segment's topics (by declared language). Real reach depends on content "
    "quality, delivery, budget, and user attention."
)


def validate_rule(rule: dict) -> list[str]:
    """Return a list of problems with a segment rule; empty means valid."""
    problems: list[str] = []
    if not isinstance(rule, dict):
        return ["rule must be an object"]
    for key in rule:
        if key in FORBIDDEN_RULE_KEYS:
            problems.append(f"rule key '{key}' may carry private data — forbidden")
        elif key not in ALLOWED_RULE_KEYS:
            problems.append(f"rule key '{key}' is not an allowed signal")
    topics = rule.get("topics") or []
    if not isinstance(topics, list):
        problems.append("rule.topics must be a list")
    else:
        unknown = [t for t in topics if t not in TAXONOMY_SLUGS]
        if unknown:
            problems.append(f"topics not in taxonomy: {unknown}")
    langs = rule.get("languages") or []
    if not isinstance(langs, list):
        problems.append("rule.languages must be a list")
    return problems


async def estimate_segment_size(db: AsyncSession, topics: list[str],
                                languages: list[str]) -> int:
    """Distinct opted-in users overlapping the segment's topics (and declared
    locales when the segment lists languages). Aggregate count only."""
    if not topics and not languages:
        return 0
    stmt = select(func.count(func.distinct(UserInterest.user_id)))
    if topics:
        stmt = stmt.where(UserInterest.topic_slug.in_(topics))
    if languages:
        stmt = (stmt.join(User, User.id == UserInterest.user_id)
                .where(User.locale.in_(languages)))
    return int((await db.execute(stmt)).scalar() or 0)


async def refresh_size_estimate(db: AsyncSession,
                                segment: AudienceSegment) -> int:
    segment.size_estimate = await estimate_segment_size(
        db, list(segment.topics or []), list(segment.languages or []))
    return segment.size_estimate


def build_segment(name: str, description: str, topics: list[str],
                  languages: list[str], hashtags: list[str] | None = None,
                  categories: list[str] | None = None,
                  created_by: str = "system") -> AudienceSegment:
    """Construct (not persist) a segment definition after rule validation."""
    rule = {
        "topics": list(topics),
        "languages": list(languages),
        "hashtags": list(hashtags or []),
        "categories": list(categories or []),
    }
    problems = validate_rule(rule)
    if problems:
        raise ValueError("; ".join(problems))
    signals = ["opt_in_topics", "taxonomy"]
    if languages:
        signals.append("declared_language")
    if hashtags:
        signals.append("content_hashtags")
    if categories:
        signals.append("content_category")
    return AudienceSegment(
        name=name, description=description, rule=rule,
        signals_used=signals, topics=list(topics), languages=list(languages),
        created_by=created_by,
        explanation=(
            "Built from Virello's topic taxonomy and aggregate opt-in "
            "counts. Per-user membership is NOT stored — it is computed at "
            "match time from users' declared interests. "
            + SIZE_ESTIMATE_DISCLAIMER
        ),
    )


# Curated default clusters over the 24-topic taxonomy. (name, topics, languages)
_DEFAULT_CLUSTERS: list[tuple[str, list[str], list[str]]] = [
    ("Tech & Gaming", ["technology", "gaming"], ["en", "ur"]),
    ("Lifestyle & Fashion", ["fashion", "beauty", "lifestyle"], ["en", "ur"]),
    ("Food & Travel", ["food", "travel"], ["en", "ur"]),
    ("Fitness & Health", ["fitness", "health"], ["en", "ur"]),
    ("Business & Finance", ["business", "finance", "marketing", "realestate"],
     ["en", "ur"]),
    ("Entertainment", ["music", "comedy"], ["en", "ur"]),
    ("Learning & Motivation", ["education", "motivation"], ["en", "ur"]),
    ("Sports & Autos", ["sports", "automobiles"], ["en", "ur"]),
    ("Arts & Photography", ["art", "photography"], ["en", "ur"]),
    ("Family & Pets", ["parenting", "pets"], ["en", "ur"]),
    ("News & Current Affairs", ["news"], ["en", "ur"]),
    ("Urdu Speakers", [], ["ur"]),
]


async def seed_default_segments(db: AsyncSession) -> list[AudienceSegment]:
    """Create the default taxonomy-based segments if none exist. Idempotent."""
    existing = (await db.execute(select(func.count())
                                 .select_from(AudienceSegment))).scalar()
    if existing:
        return []
    created: list[AudienceSegment] = []
    for name, topics, languages in _DEFAULT_CLUSTERS:
        seg = build_segment(
            name=name,
            description=f"Users interested in: {', '.join(topics) or 'Urdu-language content'}.",
            topics=topics, languages=languages, created_by="system")
        seg.size_estimate = await estimate_segment_size(db, topics, languages)
        db.add(seg)
        created.append(seg)
    await db.commit()
    for seg in created:
        await db.refresh(seg)
    return created


async def list_active_segments(db: AsyncSession) -> list[AudienceSegment]:
    """Active segments, auto-seeding the defaults on first use."""
    rows = (await db.execute(
        select(AudienceSegment).where(AudienceSegment.is_active.is_(True))
        .order_by(AudienceSegment.name))).scalars().all()
    if not rows:
        rows = await seed_default_segments(db)
    return list(rows)
