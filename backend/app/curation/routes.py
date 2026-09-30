"""Curation HTTP surface.

- GET /gallery/{filename}: serves product gallery images volume-first
  (VIRELLO_GALLERY_DIR, e.g. Railway /data/gallery), falling back to the
  git-committed backend/app/static/gallery. Replaces the plain StaticFiles
  mount so runtime-generated images survive on the persistent volume.
- GET /api/v1/curation/status: admin-only read-only status of the
  autonomous curation loop (last run + per-department coverage).
"""
from __future__ import annotations

import re
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.curation import config
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
