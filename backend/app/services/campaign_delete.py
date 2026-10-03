"""Shared campaign-delete cascade.

Extracted from the user-facing DELETE /campaigns/{id} so the admin panel
can delete any campaign with the exact same child cleanup (no FK
violations, no orphans). Behaviour is unchanged for the user flow.
"""
from __future__ import annotations

import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.commerce import PostProduct, ShopClick
from app.models.core import (
    AgentRun,
    AuditLog,
    Campaign,
    FraudFlag,
    MetricDaily,
)
from app.models.growth import DiscoveryInteraction, DiscoveryPlacement
from app.models.growth_engine import (
    GrowthDecision,
    GrowthLoop,
    GrowthObservation,
    GrowthRound,
    GrowthSegment,
    GrowthVariant,
)
from app.models.social_metrics import SocialMetricSnapshot


async def delete_campaign_cascade(
    db: AsyncSession,
    campaign: Campaign,
    *,
    actor_id: uuid.UUID,
    audit_action: str,
) -> None:
    """Delete a campaign and every row that references it, then audit-log.

    Children are removed before the campaign row itself (Postgres has no
    ON DELETE CASCADE here), mirroring the original user-delete endpoint.
    Does NOT commit — the caller commits.
    """
    # Product tags + tracked clicks hang off the campaign's placements
    # (FK to discovery_placements.id, no ON DELETE CASCADE) — they must go
    # before the placements themselves or Postgres raises an FK violation.
    placement_ids = select(DiscoveryPlacement.id).where(
        DiscoveryPlacement.campaign_id == campaign.id)
    await db.execute(
        delete(PostProduct).where(PostProduct.post_id.in_(placement_ids)))
    await db.execute(
        delete(ShopClick).where(ShopClick.post_id.in_(placement_ids)))
    for model in (
        AgentRun,
        MetricDaily,
        FraudFlag,
        DiscoveryPlacement,
        DiscoveryInteraction,
        SocialMetricSnapshot,
    ):
        await db.execute(delete(model).where(model.campaign_id == campaign.id))
    loops = (
        (
            await db.execute(
                select(GrowthLoop).where(GrowthLoop.campaign_id == campaign.id)
            )
        )
        .scalars()
        .all()
    )
    for loop in loops:
        for child_model, col in (
            (GrowthSegment, GrowthSegment.loop_id),
            (GrowthVariant, GrowthVariant.loop_id),
            (GrowthRound, GrowthRound.loop_id),
            (GrowthObservation, GrowthObservation.loop_id),
            (GrowthDecision, GrowthDecision.loop_id),
        ):
            await db.execute(delete(child_model).where(col == loop.id))
        await db.delete(loop)
    db.add(
        AuditLog(
            user_id=actor_id,
            action=audit_action,
            details=str(campaign.id),
        )
    )
    await db.delete(campaign)
