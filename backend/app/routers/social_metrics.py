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

import hmac
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import Campaign, User
from app.models.social_metrics import AccountMetricSnapshot, SocialMetricSnapshot
from app.services.social_metrics import (
    METRIC_KEYS,
    ManualMetricsProvider,
    SocialMetricsValidationError,
    validate_metrics,
)

router = APIRouter()

_DISCLAIMER = (
    "These are official numbers from the platform (supplied by the creator "
    "from the platform's official dashboard, or fetched via a connected "
    "account once available). Virello never fabricates platform metrics; "
    "they are kept separate from Virello's own Discovery-interaction counts."
)

_ALLOWED_PLATFORMS = {"instagram", "facebook", "tiktok", "youtube", "other"}

# Honest source labels per platform for account-level snapshots. Only
# platforms with a real ingestion path are listed; unknown platforms are
# rejected (400) rather than stamped with a made-up source.
_ACCOUNT_SOURCES = {
    "instagram": "instagram:account-insights",
    "facebook": "facebook:page-insights",
    "tiktok": "tiktok:analytics-api",
    "youtube": "youtube:analytics-api",
}

_AGENT_EMAIL = "metrics-agent@virello.local"
_service_bearer = HTTPBearer(auto_error=False)


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


async def _get_or_create_agent_user(db: AsyncSession) -> User:
    """Owner-scoping identity for the MetricsAgent worker.

    Snapshots written by the worker belong to this service user, exactly like
    every other owner-scoped row in the schema.
    """
    user = (await db.execute(
        select(User).where(User.email == _AGENT_EMAIL))).scalar_one_or_none()
    if user is None:
        user = User(email=_AGENT_EMAIL, name="Metrics Agent")
        db.add(user)
        await db.flush()
    return user


async def get_metrics_agent(
    db: AsyncSession = Depends(get_db),
    creds: HTTPAuthorizationCredentials | None = Depends(_service_bearer),
) -> User:
    """Service-token auth for the MetricsAgent worker.

    Fails closed: 503 when VIRELLO_METRICS_AGENT_TOKEN is unset, 401 on any
    token mismatch. This is deliberately separate from the JWT user flow —
    the worker is a machine, not a signed-in user.
    """
    token = settings.metrics_agent_token
    if not token:
        raise HTTPException(503, "Metrics agent not configured")
    presented = creds.credentials if creds and creds.scheme.lower() == "bearer" else ""
    if not presented or not hmac.compare_digest(presented, token):
        raise HTTPException(401, "Invalid metrics agent token")
    return await _get_or_create_agent_user(db)


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
        metrics={k: data[k] for k in METRIC_KEYS},
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


# ---------------------------------------------------------------------------
# Account-level snapshots (MetricsAgent worker → backend → dashboard)
# ---------------------------------------------------------------------------

class AccountSnapshotIn(BaseModel):
    platform: str = Field(default="instagram", max_length=32)
    account_ref: str = Field(default="", max_length=255)
    metrics: dict = Field(default_factory=dict)
    period_days: int = Field(default=7, ge=1, le=90)


def _account_snap_json(s: AccountMetricSnapshot) -> dict:
    return {
        "id": str(s.id),
        "platform": s.platform,
        "account_ref": s.account_ref,
        "metrics": s.metrics,
        "source": s.source,
        "period_days": s.period_days,
        "captured_at": s.captured_at.isoformat() if s.captured_at else None,
    }


@router.post("/account/snapshot")
async def create_account_snapshot(
    body: AccountSnapshotIn,
    db: AsyncSession = Depends(get_db),
    agent: User = Depends(get_metrics_agent),
) -> dict:
    """Record one account-level official-metrics reading (MetricsAgent only).

    Service-token auth. The worker posts only honestly-measured keys;
    validate_metrics() normalizes the rest (documented 0-fill). The source
    label always names the real origin — never fabricated.
    """
    platform = body.platform.strip().lower()
    source = _ACCOUNT_SOURCES.get(platform)
    if source is None:
        raise HTTPException(
            400, f"platform must be one of {sorted(_ACCOUNT_SOURCES)}")
    try:
        data = validate_metrics(body.metrics)
    except SocialMetricsValidationError as e:
        raise HTTPException(400, str(e))
    snap = AccountMetricSnapshot(
        user_id=agent.id,
        platform=platform,
        account_ref=body.account_ref.strip(),
        metrics={k: data[k] for k in METRIC_KEYS},
        source=source,
        period_days=body.period_days,
    )
    db.add(snap)
    await db.commit()
    await db.refresh(snap)
    return {"snapshot": _account_snap_json(snap), "disclaimer": _DISCLAIMER}


@router.get("/account/latest")
async def latest_account_snapshot(
    platform: str = Query(default="instagram", max_length=32),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """Latest account-level snapshot for the requesting user + platform.

    Returns {"snapshot": null} when none exists — the dashboard must fall
    back to its demo view; zeros are never presented as measured data.
    """
    platform = platform.strip().lower()
    snap = (await db.execute(
        select(AccountMetricSnapshot)
        .where(AccountMetricSnapshot.user_id == user.id,
               AccountMetricSnapshot.platform == platform)
        .order_by(AccountMetricSnapshot.captured_at.desc())
        .limit(1)
    )).scalar_one_or_none()
    return {
        "snapshot": _account_snap_json(snap) if snap else None,
        "disclaimer": _DISCLAIMER,
    }


@router.get("/account/timeseries")
async def account_timeseries(
    platform: str = Query(default="instagram", max_length=32),
    days: int = Query(default=12, ge=1, le=30),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """Daily account-level snapshots for the reach chart (owner only).

    One snapshot per calendar day (latest per day), ascending, covering the
    last `days` days. Empty list when no data — never fabricated points.
    """
    platform = platform.strip().lower()
    since = datetime.now(timezone.utc) - timedelta(days=days)
    snaps = (await db.execute(
        select(AccountMetricSnapshot)
        .where(AccountMetricSnapshot.user_id == user.id,
               AccountMetricSnapshot.platform == platform,
               AccountMetricSnapshot.captured_at >= since)
        .order_by(AccountMetricSnapshot.captured_at.desc())
    )).scalars().all()
    # DB-agnostic per-day dedupe: latest snapshot wins per calendar day.
    per_day: dict = {}
    for s in snaps:
        day = s.captured_at.date().isoformat() if s.captured_at else "unknown"
        per_day.setdefault(day, s)
    ordered = sorted(per_day.values(),
                     key=lambda s: s.captured_at or datetime.min.replace(tzinfo=timezone.utc))
    return {
        "platform": platform,
        "days": days,
        "snapshots": [_account_snap_json(s) for s in ordered],
        "disclaimer": _DISCLAIMER,
    }
