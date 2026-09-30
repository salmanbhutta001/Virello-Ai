"""User posts — edit/delete your OWN feed posts.

A "post" is a DiscoveryPlacement: a campaign the user shared to the
discovery feed (optionally with tagged products). All mutations here are
owner-only: the placement's campaign must belong to the caller, enforced
server-side (404 for missing OR not-owned, so ownership never leaks).

- PATCH /api/v1/posts/{placement_id} — edit topics. Editing a rejected
  post resubmits it for review (status back to pending).
- DELETE /api/v1/posts/{placement_id} — remove the post from the feed,
  cascading its product tags and tracked clicks. The campaign itself is
  NOT deleted (use DELETE /api/v1/campaigns/{id} for that). Any points
  awarded for creating the post are reversed.
"""
from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.commerce import PostProduct, ShopClick
from app.models.core import AuditLog, Campaign, User
from app.models.growth import DiscoveryPlacement

log = logging.getLogger(__name__)

router = APIRouter()

_MAX_TOPICS = 5


class PostEditIn(BaseModel):
    topics: list[str] = []


async def _owned_placement(    db: AsyncSession, user: User, placement_id: uuid.UUID
) -> tuple[DiscoveryPlacement, Campaign]:
    """Placement + campaign, or 404 when missing/not owned (no leak)."""
    try:
        pid = uuid.UUID(str(placement_id))
    except ValueError:
        raise HTTPException(404, "Post not found")
    row = (await db.execute(
        select(DiscoveryPlacement, Campaign)
        .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
        .where(DiscoveryPlacement.id == pid, Campaign.user_id == user.id)
    )).one_or_none()
    if row is None:
        raise HTTPException(404, "Post not found")
    return row[0], row[1]


def _post_to_dict(p: DiscoveryPlacement, c: Campaign,
                  default_reward_cents: int = 5) -> dict:
    reward_cents = (p.reward_cents if p.reward_cents is not None
                    else default_reward_cents)
    return {
        "placement_id": str(p.id),
        "campaign_id": str(c.id),
        "title": c.title,
        "post_url": c.post_url,
        "platform": c.platform,
        "topics": p.topics or [],
        "status": p.status,
        "review_note": p.review_note,
        "reward_cents": reward_cents,
        "reward_display": f"+${reward_cents // 100}.{reward_cents % 100:02d}",
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }


@router.get("/mine")
async def my_posts(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """The caller's own feed posts (placements), newest first."""
    from app.services import reward_claims as claims_svc
    default_reward = await claims_svc.get_default_post_reward_cents(db)
    rows = (await db.execute(
        select(DiscoveryPlacement, Campaign)
        .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
        .where(Campaign.user_id == user.id)
        .order_by(DiscoveryPlacement.created_at.desc())
    )).all()
    return {"posts": [_post_to_dict(p, c, default_reward) for p, c in rows]}


@router.patch("/{placement_id}")
async def edit_post(
    placement_id: str,
    body: PostEditIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """Owner edits their post's topics. A rejected post is resubmitted."""
    placement, campaign = await _owned_placement(db, user, placement_id)
    topics = [t.strip() for t in (body.topics or []) if t and t.strip()]
    if not topics:
        raise HTTPException(400, "At least one topic is required")
    if len(topics) > _MAX_TOPICS:
        raise HTTPException(400, f"At most {_MAX_TOPICS} topics")
    placement.topics = topics
    resubmitted = False
    if placement.status == "rejected":
        placement.status = "pending"
        placement.review_note = ""
        placement.reviewed_at = None
        resubmitted = True
    db.add(AuditLog(user_id=user.id, action="post.edit",
                    details=str(placement.id)))
    await db.commit()
    await db.refresh(placement)
    from app.services import reward_claims as claims_svc
    default_reward = await claims_svc.get_default_post_reward_cents(db)
    out = _post_to_dict(placement, campaign, default_reward)
    out["resubmitted"] = resubmitted
    return out


@router.delete("/{placement_id}")
async def delete_post(
    placement_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """Owner deletes their post: tags + tracked clicks cascade, points for
    creating the post are reversed. The campaign itself is kept."""
    placement, campaign = await _owned_placement(db, user, placement_id)
    pid = placement.id

    await db.execute(delete(PostProduct).where(PostProduct.post_id == pid))
    await db.execute(delete(ShopClick).where(ShopClick.post_id == pid))

    reversed_points = 0
    try:
        from app.models.rewards import PointsLedger
        paid = (await db.execute(
            select(func.coalesce(func.sum(PointsLedger.delta), 0))
            .where(PointsLedger.user_id == user.id,
                   PointsLedger.reason.in_(("post_created", "post_with_products")),
                   PointsLedger.ref_id == str(campaign.id),
                   PointsLedger.delta > 0)
        )).scalar() or 0
        if paid > 0:
            already = (await db.execute(
                select(func.count()).select_from(PointsLedger)
                .where(PointsLedger.user_id == user.id,
                       PointsLedger.reason == "post_deleted_reversal",
                       PointsLedger.ref_id == f"reversal:{pid}")
            )).scalar() or 0
            if not already:
                db.add(PointsLedger(user_id=user.id, delta=-int(paid),
                                    reason="post_deleted_reversal",
                                    ref_id=f"reversal:{pid}"))
                reversed_points = int(paid)
    except Exception:
        log.exception("post delete: points reversal skipped")

    db.add(AuditLog(user_id=user.id, action="post.delete",
                    details=str(pid)))
    await db.delete(placement)
    await db.commit()
    return {"deleted": True, "placement_id": str(pid),
            "points_reversed": reversed_points}
