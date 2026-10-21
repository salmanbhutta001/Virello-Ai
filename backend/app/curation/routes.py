"""Curation HTTP surface.

- GET /gallery/{filename}: serves product gallery images volume-first
  (VIRELLO_GALLERY_DIR, e.g. Railway /data/gallery), falling back to the
  git-committed backend/app/static/gallery. Replaces the plain StaticFiles
  mount so runtime-generated images survive on the persistent volume.
- GET /api/v1/curation/status: admin-only read-only status of the
  autonomous curation loop (last run + per-department coverage).
"""
from __future__ import annotations

import asyncio
import os
import re
import secrets
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.curation import config
from app.curation.discovery import add_candidate
from app.curation.models import CurationCandidate, CurationRun
from app.curation.service import department_counts
from app.models.core import User
from app.routers.admin import require_admin

router = APIRouter()

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.\-]*\.(jpg|jpeg|png|webp)$",
                        re.IGNORECASE)


def resolve_gallery_file(filename: str) -> Path | None:
    """Volume-first, static-dir fallback. None when missing/unsafe."""
    if not _SAFE_NAME.match(filename or ""):
        return None
    for base in (config.gallery_dir(), config.static_gallery_dir()):
        p = base / filename
        if p.is_file():
            return p
    return None


@router.get("/gallery/{filename}")
async def serve_gallery_file(filename: str):
    """Public product image. No auth — same as before, now volume-aware."""
    path = resolve_gallery_file(filename)
    if path is None:
        raise HTTPException(404, "Not found")
    return FileResponse(str(path))


@router.get("/api/v1/curation/status")
async def curation_status(
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Admin-only. Last curation run, per-department product counts, and
    the pending candidate queue depth."""
    last = (await db.execute(
        select(CurationRun).order_by(CurationRun.started_at.desc()).limit(1)
    )).scalar_one_or_none()
    counts = await department_counts(db)
    pending = (await db.execute(
        select(func.count(CurationCandidate.id))
        .where(CurationCandidate.status == "pending")
    )).scalar() or 0
    return {
        "enabled": config.curation_enabled(),
        "interval_hours": config.curation_interval_hours(),
        "gallery_dir": str(config.gallery_dir()),
        "last_run": None if last is None else {
            "started_at": last.started_at.isoformat() if last.started_at else None,
            "finished_at": last.finished_at.isoformat() if last.finished_at else None,
            "status": last.status,
            "departments_covered": last.departments_covered,
            "departments_total": last.departments_total,
            "products_created": last.products_created,
        },
        "departments": {d: counts.get(d, 0) for d in config.DEPARTMENTS},
        "pending_candidates": int(pending),
        "note": ("Auto-listed galleries pass integrity checks only; "
                 "visual fidelity review is recommended before promoting "
                 "products."),
    }


# ---------------------------------------------------------------------------
# Manual controls (Hafiz, 2026-10-21): the curation system must be fully
# operable by hand — no Muse / external operator required. Both endpoints
# accept EITHER an admin login (same rule as the status endpoint) OR the
# service-to-service X-Curator-Token header (VIRELLO_CURATOR_TOKEN).
# ---------------------------------------------------------------------------

def _curator_token_ok(token: str | None) -> bool:
    expected = os.environ.get("VIRELLO_CURATOR_TOKEN", "")
    return (bool(expected) and bool(token)
            and secrets.compare_digest(token, expected))


async def _require_admin_or_curator(request: Request,
                                    db: AsyncSession) -> None:
    if _curator_token_ok(request.headers.get("x-curator-token")):
        return
    auth = request.headers.get("authorization", "")
    if auth.lower().startswith("bearer "):
        from app.core.security import decode_token
        try:
            user_id = decode_token(auth[7:].strip())
        except ValueError:
            user_id = ""
        if user_id:
            user = (await db.execute(
                select(User).where(User.id == user_id))).scalar_one_or_none()
            if user is not None:
                await require_admin(user)  # raises 403 when not an admin
                return
    raise HTTPException(401, "Admin login or curator token required")


_run_lock = asyncio.Lock()


async def _run_cycle_once() -> None:
    import logging
    log = logging.getLogger("virello.curation.routes")
    from app.core.database import SessionLocal
    from app.curation.service import run_curation_cycle
    try:
        async with SessionLocal() as db:
            report = await run_curation_cycle(db)
        log.info("manual curation cycle finished: %s (%s/%s departments, "
                 "%s created)", report.get("status"),
                 report.get("departments_covered"),
                 len(config.DEPARTMENTS), report.get("products_created"))
    except Exception:
        log.exception("manual curation cycle crashed")
    finally:
        if _run_lock.locked():
            _run_lock.release()


@router.post("/api/v1/curation/run")
async def curation_run_now(request: Request,
                           db: AsyncSession = Depends(get_db)) -> dict:
    """Trigger one curation cycle immediately, in the background.

    The scheduled 3-hourly cycle keeps running regardless; this is the
    manual 'run it now' button for an operator."""
    await _require_admin_or_curator(request, db)
    if _run_lock.locked():
        raise HTTPException(409, "A manual curation cycle is already running")
    await _run_lock.acquire()
    asyncio.create_task(_run_cycle_once())
    return {"started": True,
            "note": "Cycle running in the background — watch "
                    "GET /api/v1/curation/status for the result."}


class CandidateIn(BaseModel):
    asin: str = Field(..., max_length=10)
    title: str = Field(..., max_length=200)
    department: str = Field(..., max_length=40)
    main_image_url: str = Field(default="", max_length=1000)


class CandidatesIn(BaseModel):
    candidates: list[CandidateIn] = Field(..., min_length=1, max_length=25)


@router.post("/api/v1/curation/candidates")
async def curation_add_candidates(payload: CandidatesIn, request: Request,
                                  db: AsyncSession = Depends(get_db)) -> dict:
    """Feed the candidate queue by hand. The next cycle (scheduled or
    manually triggered) builds a verified gallery for each candidate and
    lists it — gallery-first, incomplete galleries are skipped."""
    await _require_admin_or_curator(request, db)
    added = 0
    for c in payload.candidates:
        dept = c.department.strip().lower()
        if dept not in config.DEPARTMENTS:
            raise HTTPException(400, f"Unknown department: {c.department}")
        await add_candidate(db, asin=c.asin, title=c.title, department=dept,
                            source="manual", main_image_url=c.main_image_url)
        added += 1
    await db.commit()
    return {"added": added,
            "note": "Candidates are listed by the next curation cycle."}
