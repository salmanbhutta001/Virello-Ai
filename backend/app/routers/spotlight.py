"""Virello Spotlight API — opt-in creator featuring.

POST /submit is public: any user can submit their content for featuring,
but ONLY with explicit consent (consent=true required). Queue + review are
admin-only (Hafiz). Posting to Virello's social accounts is manual in v1 —
Hafiz posts approved submissions with the "Featured Creator" disclosure.
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.spotlight import SpotlightSubmission
from app.routers.admin import require_admin

router = APIRouter()


class SpotlightSubmitIn(BaseModel):
    content: str = Field(min_length=3, max_length=2000)
    link: str = Field(default="", max_length=300)
    creator_handle: str = Field(default="", max_length=80)
    creator_email: str = Field(default="", max_length=255)
    # Explicit opt-in — the frontend shows exactly what this means.
    consent: bool = False


class SpotlightReviewIn(BaseModel):
    status: str = Field(pattern="^(approved|rejected|posted)$")
    note: str = Field(default="", max_length=500)


@router.post("/submit")
async def submit_spotlight(body: SpotlightSubmitIn,
                           db: AsyncSession = Depends(get_db)):
    """Submit content for Virello Spotlight featuring. Requires explicit
    consent — without it, nothing is stored."""
    if not body.consent:
        raise HTTPException(
            status_code=400,
            detail="Please tick the consent checkbox — Virello only features "
                   "content you explicitly agree to share.",
        )
    sub = SpotlightSubmission(
        content=body.content.strip(),
        link=body.link.strip(),
        creator_handle=body.creator_handle.strip(),
        creator_email=body.creator_email.strip(),
        consent=True,
        consent_at=datetime.now(timezone.utc),
        status="pending",
    )
    db.add(sub)
    await db.commit()
    return {
        "ok": True,
        "message": "Submitted for review. If approved, Virello will feature "
                   "it on our official accounts with credit to you — "
                   "labeled as a Featured Creator post.",
    }


@router.get("/queue")
async def spotlight_queue(status: str = "pending", limit: int = 50,
                          db: AsyncSession = Depends(get_db),
                          _admin=Depends(require_admin)):
    """Admin: list submissions for review (Hafiz)."""
    q = select(SpotlightSubmission)
    if status in ("pending", "approved", "rejected", "posted"):
        q = q.where(SpotlightSubmission.status == status)
    q = q.order_by(desc(SpotlightSubmission.created_at)).limit(min(limit, 200))
    rows = (await db.execute(q)).scalars().all()
    return [
        {
            "id": str(r.id),
            "content": r.content,
            "link": r.link,
            "creator_handle": r.creator_handle,
            "creator_email": r.creator_email,
            "consent": r.consent,
            "consent_at": r.consent_at.isoformat() if r.consent_at else None,
            "status": r.status,
            "admin_note": r.admin_note,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


@router.post("/{submission_id}/review")
async def review_spotlight(submission_id: str, body: SpotlightReviewIn,
                           db: AsyncSession = Depends(get_db),
                           _admin=Depends(require_admin)):
    """Admin: approve / reject / mark-as-posted a submission (Hafiz)."""
    row = (await db.execute(
        select(SpotlightSubmission).where(
            SpotlightSubmission.id == submission_id))).scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Submission not found.")
    row.status = body.status
    row.admin_note = body.note.strip()
    row.reviewed_at = datetime.now(timezone.utc)
    await db.commit()
    return {"ok": True, "id": str(row.id), "status": row.status}
