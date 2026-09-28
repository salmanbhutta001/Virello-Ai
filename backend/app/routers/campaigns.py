"""Campaigns — LET AI GROW with real persistence + orchestrator pipeline."""
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, HttpUrl
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import AuditLog, Campaign, CampaignGoal, CampaignStatus, GrowthMode, User
from app.services.pipeline import launch_pipeline

router = APIRouter()


class GrowRequestIn(BaseModel):
    post_url: HttpUrl
    platform: str = "auto"
    goal: CampaignGoal
    markets: list[str] = ["worldwide"]
    mode: GrowthMode
    budget_usd: float | None = None
    duration_days: int = 7


class CampaignOut(BaseModel):
    id: str
    title: str
    post_url: str
    platform: str
    goal: str
    mode: str
    markets: str
    status: str
    budget_usd: float
    spend_usd: float

    @classmethod
    def from_row(cls, c: Campaign) -> "CampaignOut":
        return cls(
            id=str(c.id), title=c.title, post_url=c.post_url, platform=c.platform,
            goal=c.goal.value, mode=c.mode.value, markets=c.markets,
            status=c.status.value, budget_usd=c.budget_usd, spend_usd=c.spend_usd,
        )


@router.post("", status_code=201, response_model=CampaignOut)
async def create_campaign(
    req: GrowRequestIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CampaignOut:
    """LET AI GROW: validate limits, persist, enqueue orchestrator pipeline."""
    if req.mode == GrowthMode.paid:
        if not req.budget_usd or req.budget_usd <= 0:
            raise HTTPException(400, "Paid Boost requires budget_usd > 0.")
        if req.budget_usd > 10000:
            raise HTTPException(400, "Budget exceeds per-campaign cap.")
    budget = req.budget_usd or 0.0

    campaign = Campaign(
        user_id=user.id,
        title=str(req.post_url)[:120],
        post_url=str(req.post_url),
        platform=req.platform,
        goal=req.goal,
        mode=req.mode,
        markets=",".join(req.markets),
        status=CampaignStatus.analyzing,
        budget_usd=budget,
        duration_days=req.duration_days,
    )
    db.add(campaign)
    db.add(AuditLog(user_id=user.id, action="campaign.create",
                    details=f"mode={req.mode.value} budget={budget}"))
    await db.commit()
    await db.refresh(campaign)

    launch_pipeline(str(campaign.id))
    await db.refresh(campaign)  # eager mode may have already advanced stages
    return CampaignOut.from_row(campaign)


@router.get("", response_model=list[CampaignOut])
async def list_campaigns(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[CampaignOut]:
    res = await db.execute(
        select(Campaign).where(Campaign.user_id == user.id).order_by(Campaign.created_at.desc())
    )
    return [CampaignOut.from_row(c) for c in res.scalars().all()]


@router.get("/{campaign_id}", response_model=CampaignOut)
async def get_campaign(
    campaign_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CampaignOut:
    campaign = await _owned(db, user, campaign_id)
    return CampaignOut.from_row(campaign)


@router.post("/{campaign_id}/pause", response_model=CampaignOut)
async def pause_campaign(
    campaign_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CampaignOut:
    """User (or Fraud & Safety Agent) pauses. Audit-logged."""
    campaign = await _owned(db, user, campaign_id)
    campaign.status = CampaignStatus.paused
    db.add(AuditLog(user_id=user.id, action="campaign.pause", details=str(campaign_id)))
    await db.commit()
    await db.refresh(campaign)
    return CampaignOut.from_row(campaign)


async def _owned(db: AsyncSession, user: User, campaign_id: uuid.UUID) -> Campaign:
    res = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id, Campaign.user_id == user.id)
    )
    campaign = res.scalar_one_or_none()
    if campaign is None:
        raise HTTPException(404, "Campaign not found")
    return campaign


# ---------------------------------------------------------------------------
# Trackable campaign links — real click tracking for shared links.
#
# GET /api/v1/campaigns/{id}/share-link -> returns the public trackable URL
# GET /c/{campaign_id} (public, no auth) -> logs click, redirects to post_url
#
# When the owner shares this link on WhatsApp/Instagram/etc, every real
# visitor is counted. No fake data — only genuine HTTP visits.
# ---------------------------------------------------------------------------
class ShareLinkOut(BaseModel):
    campaign_id: str
    share_url: str
    post_url: str


@router.get("/{campaign_id}/share-link", response_model=ShareLinkOut)
async def get_share_link(
    campaign_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ShareLinkOut:
    """Get the public trackable share link for a campaign."""
    from app.core.config import settings
    campaign = await _owned(db, user, campaign_id)
    base = getattr(settings, "public_base_url",
                   "https://virello-api-production.up.railway.app")
    return ShareLinkOut(
        campaign_id=str(campaign.id),
        share_url=f"{base}/c/{campaign.id}",
        post_url=campaign.post_url,
    )


@router.get("/{campaign_id}/stats")
async def campaign_stats(
    campaign_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """Real campaign stats from genuine tracked events only."""
    from sqlalchemy import func
    from app.models.core import MetricDaily
    campaign = await _owned(db, user, campaign_id)

    res = await db.execute(
        select(
            func.sum(MetricDaily.impressions).label("impressions"),
            func.sum(MetricDaily.reach).label("reach"),
            func.sum(MetricDaily.clicks).label("clicks"),
            func.sum(MetricDaily.engagement).label("engagement"),
        ).where(MetricDaily.campaign_id == campaign.id)
    )
    row = res.one()
    return {
        "campaign_id": str(campaign.id),
        "impressions": int(row.impressions or 0),
        "reach": int(row.reach or 0),
        "clicks": int(row.clicks or 0),
        "engagement": int(row.engagement or 0),
        "note": "Real tracked events only. Zero means no genuine visits yet.",
    }
