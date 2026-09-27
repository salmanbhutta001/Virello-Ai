from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User, UserActivity

router = APIRouter()

# Event-type buckets over genuine ad_impressions (never estimates).
from app.models.ad_attribution import AdConversion  # noqa: E402
from app.models.ad_delivery import AdEventType, AdImpression  # noqa: E402
from app.models.ads import AdCampaign  # noqa: E402

_IMPRESSION_EVENTS = (AdEventType.impression, AdEventType.view)
_ENGAGEMENT_EVENTS = (
    AdEventType.like,
    AdEventType.save,
    AdEventType.visit,
    AdEventType.follow,
    AdEventType.click,
)
_CLICK_EVENTS = (AdEventType.click, AdEventType.visit)

_TIMESERIES_METRICS = {
    "reach": _IMPRESSION_EVENTS,
    "impressions": _IMPRESSION_EVENTS,
    "engagement": _ENGAGEMENT_EVENTS,
    "clicks": _CLICK_EVENTS,
}


async def _user_campaign_ids(user: User, db: AsyncSession) -> list:
    res = await db.execute(
        select(AdCampaign.id).where(AdCampaign.owner_id == user.id))
    return list(res.scalars().all())


@router.get("/overview")
async def overview(user: User = Depends(get_current_user),
                   db: AsyncSession = Depends(get_db)) -> dict:
    """Real per-user aggregates from genuine ad_impressions.

    All numbers come from recorded events on the user's own campaigns.
    With no data every field is zero — demo numbers are never served.
    """
    campaign_ids = await _user_campaign_ids(user, db)
    if not campaign_ids:
        return {"reach": 0, "engagement_rate": 0.0,
                "clicks": 0, "conversions": 0}

    async def _count(event_types: tuple) -> int:
        res = await db.execute(
            select(func.count()).select_from(AdImpression).where(
                AdImpression.campaign_id.in_(campaign_ids),
                AdImpression.event_type.in_(event_types)))
        return res.scalar() or 0

    reach = await _count(_IMPRESSION_EVENTS)
    engagement = await _count(_ENGAGEMENT_EVENTS)
    clicks = await _count(_CLICK_EVENTS)
    conv_res = await db.execute(
        select(func.count()).select_from(AdConversion).where(
            AdConversion.campaign_id.in_(campaign_ids)))
    conversions = conv_res.scalar() or 0
    engagement_rate = round(engagement / reach * 100, 2) if reach else 0.0
    return {"reach": reach, "engagement_rate": engagement_rate,
            "clicks": clicks, "conversions": conversions}


@router.get("/campaigns/{campaign_id}/timeseries")
async def timeseries(campaign_id: str, metric: str = "reach", days: int = 7,
                     user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)) -> dict:
    """Real per-day points from genuine ad_impressions of one campaign.

    The campaign must belong to the caller; anything else is a 404.
    Empty points (not zeros-for-nothing) when there is no data.
    """
    event_types = _TIMESERIES_METRICS.get(metric)
    if event_types is None:
        raise HTTPException(
            400, f"unknown metric '{metric}' "
                 f"(expected one of {sorted(_TIMESERIES_METRICS)})")
    try:
        import uuid as _uuid
        cid = _uuid.UUID(campaign_id)
    except ValueError:
        raise HTTPException(404, "Campaign not found")
    campaign = (await db.execute(
        select(AdCampaign).where(AdCampaign.id == cid,
                                 AdCampaign.owner_id == user.id)
    )).scalar_one_or_none()
    if campaign is None:
        raise HTTPException(404, "Campaign not found")

    days = max(1, min(days, 90))
    today = datetime.now(timezone.utc).date()
    start = today - timedelta(days=days - 1)
    start_dt = datetime(start.year, start.month, start.day,
                       tzinfo=timezone.utc)

    res = await db.execute(
        select(func.date(AdImpression.occurred_at),
               func.count()).select_from(AdImpression).where(
            AdImpression.campaign_id == cid,
            AdImpression.event_type.in_(event_types),
            AdImpression.occurred_at >= start_dt)
        .group_by(func.date(AdImpression.occurred_at)))
    by_day = {str(day)[:10]: count for day, count in res.all()}

    points = []
    for i in range(days):
        day = start + timedelta(days=i)
        day_iso = day.isoformat()
        points.append({"date": day_iso, "value": by_day.get(day_iso, 0)})
    return {"campaign_id": campaign_id, "metric": metric, "points": points}


class TrackIn(BaseModel):
    # app_open | login
    event: str = "app_open"


@router.post("/track")
async def track(body: TrackIn, user: User = Depends(get_current_user),
               db: AsyncSession = Depends(get_db)) -> dict:
    """Log an app-visit event for the admin analytics dashboard.

    Throttled: at most one app_open per user per 30 minutes, so the
    user_activity table stays small while DAU/WAU/MAU stay accurate.
    """
    event = body.event if body.event in ("app_open", "login") else "app_open"
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=30)
    recent = await db.execute(
        select(func.count()).select_from(UserActivity).where(
            UserActivity.user_id == user.id,
            UserActivity.event == "app_open",
            UserActivity.created_at >= cutoff,
        )
    )
    if event == "login" or (recent.scalar() or 0) == 0:
        db.add(UserActivity(user_id=user.id, event=event))
        await db.commit()
    return {"ok": True}
