"""AI Growth Engine API — start, monitor, and audit the autonomous loop."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.models.growth import DiscoveryPlacement
from app.models.growth_engine import (
    GrowthDecision,
    GrowthLoop,
    GrowthObservation,
    GrowthRound,
    GrowthSegment,
    GrowthVariant,
)
from app.services import growth_engine as engine

router = APIRouter()


def _loop_json(loop: GrowthLoop) -> dict:
    return {
        "id": str(loop.id), "campaign_id": str(loop.campaign_id),
        "status": loop.status, "round": loop.round,
        "config": {k: v for k, v in (loop.config or {}).items()
                   if not k.startswith("_")},
        "created_at": loop.created_at.isoformat() if loop.created_at else None,
        "updated_at": loop.updated_at.isoformat() if loop.updated_at else None,
    }


def _seg_json(s: GrowthSegment) -> dict:
    return {"id": str(s.id), "name": s.name, "topics": s.topics,
            "languages": s.languages, "markets": s.markets,
            "weight": round(s.weight, 3), "prior_score": s.prior_score,
            "status": s.status}


def _var_json(v: GrowthVariant) -> dict:
    return {"id": str(v.id), "label": v.label, "kind": v.kind,
            "content": v.content, "rationale": v.rationale,
            "weight": round(v.weight, 3), "is_original": v.is_original,
            "status": v.status}


class LoopIn(BaseModel):
    campaign_id: str
    config: dict = {}


@router.post("/loops")
async def start(body: LoopIn, db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    try:
        loop = await engine.start_loop(db, user, uuid.UUID(body.campaign_id),
                                       body.config or None)
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    return {"loop": _loop_json(loop)}


@router.get("/campaigns/{campaign_id}/loop")
async def for_campaign(campaign_id: str, db: AsyncSession = Depends(get_db),
                       user: User = Depends(get_current_user)) -> dict:
    loop = await engine.get_loop_for_campaign(db, uuid.UUID(campaign_id))
    if loop is None or loop.user_id != user.id:
        return {"loop": None}
    return {"loop": _loop_json(loop)}


async def _owned_loop(db: AsyncSession, user: User, loop_id: str) -> GrowthLoop:
    loop = await engine.get_loop(db, uuid.UUID(loop_id))
    if loop is None or loop.user_id != user.id:
        raise HTTPException(404, "Growth loop not found")
    return loop


@router.get("/loops/{loop_id}")
async def detail(loop_id: str, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    loop = await _owned_loop(db, user, loop_id)
    segments = await engine._segments(db, loop.id)
    variants = await engine._variants(db, loop.id)
    rounds = (await db.execute(select(GrowthRound).where(
        GrowthRound.loop_id == loop.id).order_by(
            GrowthRound.number.desc()).limit(5))).scalars().all()
    obs = (await db.execute(select(GrowthObservation).where(
        GrowthObservation.loop_id == loop.id,
        GrowthObservation.round == loop.round).limit(200))).scalars().all()
    placement = (await db.execute(select(DiscoveryPlacement).where(
        DiscoveryPlacement.campaign_id == loop.campaign_id)
    )).scalar_one_or_none()
    learnings = (await db.execute(select(GrowthDecision).where(
        GrowthDecision.loop_id == loop.id,
        GrowthDecision.agent.in_(("learning", "system")))
        .order_by(GrowthDecision.created_at.desc()).limit(10))).scalars().all()
    return {
        "loop": _loop_json(loop),
        "segments": [_seg_json(s) for s in segments],
        "variants": [_var_json(v) for v in variants],
        "rounds": [{"number": r.number,
                    "summary": r.summary,
                    "started_at": r.started_at.isoformat() if r.started_at else None,
                    "ended_at": r.ended_at.isoformat() if r.ended_at else None}
                   for r in rounds],
        "observations": [{
            "round": o.round,
            "segment_id": str(o.segment_id) if o.segment_id else None,
            "variant_id": str(o.variant_id) if o.variant_id else None,
            "views": o.views, "saves": o.saves, "visits": o.visits,
            "dismissals": o.dismissals, "attribution": o.attribution}
            for o in obs],
        "learnings": [{"round": d.round, "action": d.action,
                       "details": d.details,
                       "created_at": d.created_at.isoformat() if d.created_at else None}
                      for d in learnings],
        "placement_status": placement.status if placement else None,
    }


@router.get("/loops/{loop_id}/decisions")
async def decisions(loop_id: str, limit: int = 100,
                    db: AsyncSession = Depends(get_db),
                    user: User = Depends(get_current_user)) -> dict:
    loop = await _owned_loop(db, user, loop_id)
    rows = (await db.execute(select(GrowthDecision).where(
        GrowthDecision.loop_id == loop.id).order_by(
            GrowthDecision.created_at.desc()).limit(min(limit, 500))
    )).scalars().all()
    return {"decisions": [{
        "id": str(d.id), "round": d.round, "agent": d.agent,
        "action": d.action, "details": d.details,
        "created_at": d.created_at.isoformat() if d.created_at else None}
        for d in rows]}


@router.post("/loops/{loop_id}/pause")
async def pause(loop_id: str, db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    try:
        loop = await engine.set_loop_status(db, user, uuid.UUID(loop_id), "paused")
    except ValueError as exc:
        raise HTTPException(404, str(exc))
    # set_loop_status UPDATEs the row; the server-side onupdate expires
    # updated_at, so refresh before serializing (async has no lazy IO).
    await db.refresh(loop)
    return {"loop": _loop_json(loop)}


@router.post("/loops/{loop_id}/resume")
async def resume(loop_id: str, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    try:
        loop = await engine.set_loop_status(db, user, uuid.UUID(loop_id), "running")
    except ValueError as exc:
        raise HTTPException(404, str(exc))
    await db.refresh(loop)
    return {"loop": _loop_json(loop)}


@router.post("/loops/{loop_id}/stop")
async def stop(loop_id: str, db: AsyncSession = Depends(get_db),
               user: User = Depends(get_current_user)) -> dict:
    try:
        loop = await engine.set_loop_status(db, user, uuid.UUID(loop_id), "stopped")
    except ValueError as exc:
        raise HTTPException(404, str(exc))
    await db.refresh(loop)
    return {"loop": _loop_json(loop)}


@router.post("/loops/{loop_id}/round")
async def trigger_round(loop_id: str, db: AsyncSession = Depends(get_db),
                        user: User = Depends(get_current_user)) -> dict:
    """Run one measure → learn → optimize cycle now (also used by the beat task)."""
    loop = await _owned_loop(db, user, loop_id)
    try:
        return await engine.run_round(db, loop.id)
    except ValueError as exc:
        raise HTTPException(400, str(exc))
