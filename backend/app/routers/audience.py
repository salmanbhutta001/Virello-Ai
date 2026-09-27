"""Audience Intelligence API — browse and preview audience segments.

Segments are definitions only: per-user membership is NEVER stored and is
computed at match time from opt-in data (privacy by design). Size estimates
are labeled "estimate — not a guarantee" everywhere.

Multi-source extension: /sources lists every intelligence connector with
its metadata and live status; /fingerprint builds an explainable content
fingerprint; /match scores segments with per-factor contributions (v2).
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.ads import AudienceSegment
from app.models.audience_sources import AudienceSourceSignal
from app.models.core import User
from app.routers.admin import require_admin
from app.services import audience_intelligence as ai_svc
from app.services import audience_fingerprint as fp_svc
from app.services import audience_graph as graph_svc
from app.services.audience_sources import describe_all, get_connector

router = APIRouter()


def _seg_json(s: AudienceSegment) -> dict:
    return {
        "id": str(s.id), "name": s.name, "description": s.description,
        "rule": s.rule, "signals_used": s.signals_used,
        "size_estimate": s.size_estimate,
        "languages": s.languages, "topics": s.topics,
        "is_active": s.is_active, "created_by": s.created_by,
        "explanation": s.explanation,
        "path": s.path or s.name,
        "geography": s.geography or "",
        "source_breakdown": list(s.source_breakdown or []),
        "confidence": s.confidence,
        "disclaimer": ai_svc.SIZE_ESTIMATE_DISCLAIMER,
    }


@router.get("/segments")
async def list_segments(db: AsyncSession = Depends(get_db),
                        _user: User = Depends(get_current_user)) -> dict:
    segs = await ai_svc.list_active_segments(db)
    return {"segments": [_seg_json(s) for s in segs]}


class SegmentIn(BaseModel):
    name: str
    description: str = ""
    topics: list[str] = []
    languages: list[str] = []
    hashtags: list[str] = []
    categories: list[str] = []


@router.post("/segments", status_code=201)
async def create_segment(body: SegmentIn, db: AsyncSession = Depends(get_db),
                         admin: User = Depends(require_admin)) -> dict:
    """Admin (or system) only — segment rules use legitimate signals only."""
    try:
        seg = ai_svc.build_segment(
            name=body.name.strip()[:128],
            description=body.description.strip()[:1024],
            topics=[t.strip().lower() for t in body.topics],
            languages=[l.strip().lower() for l in body.languages],
            hashtags=[h.strip().lower().lstrip("#") for h in body.hashtags],
            categories=[c.strip().lower() for c in body.categories],
            created_by="admin",
        )
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    if not seg.topics and not seg.languages:
        raise HTTPException(400, "Segment needs at least one topic or language.")
    seg.size_estimate = await ai_svc.estimate_segment_size(
        db, seg.topics, seg.languages)
    db.add(seg)
    await db.commit()
    await db.refresh(seg)
    return {"segment": _seg_json(seg)}


@router.get("/segments/{segment_id}/preview")
async def preview_segment(segment_id: str, db: AsyncSession = Depends(get_db),
                          _user: User = Depends(get_current_user)) -> dict:
    seg = (await db.execute(select(AudienceSegment).where(
        AudienceSegment.id == segment_id))).scalar_one_or_none()
    if seg is None or not seg.is_active:
        raise HTTPException(404, "Audience segment not found")
    size = await ai_svc.refresh_size_estimate(db, seg)
    await db.commit()
    return {
        "segment": _seg_json(seg),
        "preview": {
            "size_estimate": size,
            "formula": ("distinct users with opted-in interests overlapping "
                        "the segment's topics"
                        + (" and declared locale in the segment's languages"
                           if seg.languages else "")),
            "explanation": seg.explanation,
            "signals_used": seg.signals_used,
            "disclaimer": ai_svc.SIZE_ESTIMATE_DISCLAIMER,
        },
    }


# ---------------------------------------------------------------------------
# Multi-source audience intelligence
# ---------------------------------------------------------------------------

@router.get("/sources")
async def list_sources(_user: User = Depends(get_current_user)) -> dict:
    """Every connector with full metadata + live configured status."""
    return {
        "sources": describe_all(),
        "note": ("Sources aggregate PUBLIC signals into interest cohorts. "
                 "not_configured = credentials missing; no synthetic data is "
                 "ever returned."),
    }


@router.get("/sources/{source_name}/signals")
async def fetch_source_signals(
        source_name: str, topic: str = "", geography: str = "",
        limit: int = 10, _user: User = Depends(get_current_user)) -> dict:
    """Fetch live signals from one connector (graceful when unavailable)."""
    connector = get_connector(source_name)
    if connector is None:
        raise HTTPException(404, "Unknown source")
    topics = [t.strip() for t in topic.split(",") if t.strip()] or None
    result = connector.fetch_signals(
        topics=topics, geography=geography, limit=min(limit, 30))
    return {"source": source_name, **result.to_dict()}


class FingerprintIn(BaseModel):
    text: str = ""
    title: str = ""
    url: str = ""


@router.post("/fingerprint")
async def fingerprint(body: FingerprintIn,
                      _user: User = Depends(get_current_user)) -> dict:
    """Build an explainable audience fingerprint for a post/link."""
    if not (body.text.strip() or body.title.strip() or body.url.strip()):
        raise HTTPException(400, "Provide text, title, or url.")
    return {"fingerprint": fp_svc.fingerprint_content(
        text=body.text[:4000], title=body.title[:500], url=body.url[:500])}


class MatchIn(BaseModel):
    text: str = ""
    title: str = ""
    url: str = ""
    fingerprint: dict | None = None
    geography: str = ""
    threshold: float = 0.25
    limit: int = 10


@router.post("/match")
async def match_audience(body: MatchIn,
                         db: AsyncSession = Depends(get_db),
                         _user: User = Depends(get_current_user)) -> dict:
    """Score active segments against a fingerprint (v2, explainable).

    Scores are relevance fits — never reach/virality/conversion guarantees.
    """
    fp = body.fingerprint or fp_svc.fingerprint_content(
        text=body.text[:4000], title=body.title[:500], url=body.url[:500])
    if body.geography:
        fp["geography"] = body.geography[:8].upper()
    matches = await fp_svc.match_segments_v2(
        db, fp, threshold=max(0.0, min(1.0, body.threshold)),
        limit=max(1, min(25, body.limit)))
    return {
        "fingerprint": fp,
        "matches": matches,
        "weights": fp_svc.WEIGHTS_V2,
        "disclaimer": fp_svc.FINGERPRINT_DISCLAIMER,
    }


@router.post("/graph/seed", status_code=201)
async def seed_graph(db: AsyncSession = Depends(get_db),
                     admin: User = Depends(require_admin)) -> dict:
    """Seed the starter hierarchical segment graph (admin only)."""
    added = await graph_svc.seed_default_graph(db)
    await db.commit()
    return {"seeded": added}


class CacheRefreshIn(BaseModel):
    source: str
    topics: list[str] = []
    geography: str = ""


@router.post("/sources/cache", status_code=201)
async def cache_source_signals(body: CacheRefreshIn,
                               db: AsyncSession = Depends(get_db),
                               admin: User = Depends(require_admin)) -> dict:
    """Admin: fetch a connector's signals and cache the aggregates.

    Only aggregate, non-personal signals are cached. Volume is stored ONLY
    when the source provided a real number (else NULL = "volume unavailable").
    """
    connector = get_connector(body.source)
    if connector is None:
        raise HTTPException(404, "Unknown source")
    result = connector.fetch_signals(
        topics=body.topics or None, geography=body.geography, limit=30)
    stored = 0
    for s in result.signals:
        db.add(AudienceSourceSignal(
            source=s.source, topic=s.topic, keywords=s.keywords,
            geography=s.geography, language=s.language,
            volume_hint=s.volume_hint, volume_label=s.volume_label,
            trend_direction=s.trend_direction,
            raw_note=f"fetched_at={s.fetched_at.isoformat()}"))
        stored += 1
    await db.commit()
    return {"source": body.source, "status": result.status.value,
            "cached": stored, "message": result.message}
