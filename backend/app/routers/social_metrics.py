"""Official social-platform metrics API (prep layer).

- POST /api/v1/social-metrics/snapshots — record one official-metrics reading
  for a campaign. Values are validated by ManualMetricsProvider and labeled
  `source="manual:official-dashboard"`: these are the creator's own numbers,
  copied from the platform's official dashboard. Virello never fabricates
  them and never presents them as Virello-measured.
- GET /api/v1/social-metrics/campaigns/{campaign_id}/timeseries — chronological
  snapshots for a campaign (owner only).
"""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import Campaign, User
from app.models.social_metrics import SocialMetricSnapshot
from app.services.social_metrics import (
    ManualMetricsProvider,
    SocialMetricsValidationError,
)

router = APIRouter()

_DISCLAIMER = (
    "These are official numbers from the platform (supplied by the creator "
    "from the platform's official dashboard, or fetched via a connected "
    "account once available). Virello never fabricates platform metrics; "
    "they are kept separate from Virello's own Discovery-interaction counts."
)

_ALLOWED_PLATFORMS = {"instagram", "facebook", "tiktok", "youtube", "other"}


class SnapshotIn(BaseModel):
    campaign_id: uuid.UUID
    platform: str = Field(default="instagram", max_length=32)
    metrics: dict = Field(default_factory=dict)
    account_ref: str = Field(default="", max_length=255)
    post_ref: str = Field(default="", max_length=255)


async def _owned_campaign(db: AsyncSession, user: User,
                          campaign_id: uuid.UUID) -> Campaign:
    campaign = (await db.execute(
        select(Campaign).where(Campaign.id == campaign_id))).scalar_one_or_none()
    if campaign is None or campaign.user_id != user.id:
        raise HTTPException(404, "Campaign not found")
    return campaign


def _snap_json(s: SocialMetricSnapshot) -> dict:
    return {
        "id": str(s.id),
        "campaign_id": str(s.campaign_id),
        "platform": s.platform,
        "account_ref": s.account_ref,
        "post_ref": s.post_ref,
        "metrics": s.metrics,
        "source": s.source,
        "captured_at": s.captured_at.isoformat() if s.captured_at else None,
    }


@router.post("/snapshots")
async def create_snapshot(body: SnapshotIn,
                          db: AsyncSession = Depends(get_db),
                          user: User = Depends(get_current_user)) -> dict:
    await _owned_campaign(db, user, body.campaign_id)
    platform = body.platform.strip().lower()
    if platform not in _ALLOWED_PLATFORMS:
        raise HTTPException(400, f"platform must be one of {sorted(_ALLOWED_PLATFORMS)}")
    provider = ManualMetricsProvider(body.metrics)
    try:
        data = await provider.fetch_metrics(body.account_ref.strip(),
                                            body.post_ref.strip())
    except SocialMetricsValidationError as e:
        raise HTTPException(400, str(e))
    snap = SocialMetricSnapshot(
        campaign_id=body.campaign_id,
        platform=platform,
        account_ref=body.account_ref.strip(),
        post_ref=body.post_ref.strip(),
        metrics={k: data[k] for k in (
            "views", "likes", "comments", "shares", "saves", "reach",
            "followers_delta")},
        source=data["source"],
    )
    db.add(snap)
    await db.commit()
    await db.refresh(snap)
    return {"snapshot": _snap_json(snap), "disclaimer": _DISCLAIMER}


@router.get("/campaigns/{campaign_id}/timeseries")
async def timeseries(campaign_id: str,
                     db: AsyncSession = Depends(get_db),
                     user: User = Depends(get_current_user)) -> dict:
    campaign = await _owned_campaign(db, user, uuid.UUID(campaign_id))
    snaps = (await db.execute(
        select(SocialMetricSnapshot)
        .where(SocialMetricSnapshot.campaign_id == campaign.id)
        .order_by(SocialMetricSnapshot.captured_at.asc())
    )).scalars().all()
    return {
        "campaign_id": str(campaign.id),
        "snapshots": [_snap_json(s) for s in snaps],
        "disclaimer": _DISCLAIMER,
    }
