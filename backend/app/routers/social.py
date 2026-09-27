"""Following tab backend: follow / unfollow / list creators.

Honesty: a follow is only ever created by the authenticated user's explicit
request. Handles are normalized ('@Name' -> 'name') so duplicates cannot
sneak in under different casing.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.models.social import Follow

router = APIRouter()


class FollowIn(BaseModel):
    creator_handle: str
    creator_name: str | None = None


def _normalize(handle: str) -> str:
    h = handle.strip().lstrip("@").lower()
    if not h:
        raise HTTPException(400, "creator_handle must not be empty")
    return h


def _to_dict(f: Follow) -> dict:
    return {
        "creator_handle": f.creator_handle,
        "creator_name": f.creator_name,
        "followed_at": f.created_at.isoformat() if f.created_at else None,
    }


@router.post("/following")
async def follow(body: FollowIn, user: User = Depends(get_current_user),
                 db: AsyncSession = Depends(get_db)) -> dict:
    """Follow a creator. Idempotent: following twice returns the existing row."""
    handle = _normalize(body.creator_handle)
    existing = (await db.execute(
        select(Follow).where(Follow.user_id == user.id,
                             Follow.creator_handle == handle)
    )).scalar_one_or_none()
    if existing is None:
        name = (body.creator_name or "").strip() or None
        existing = Follow(user_id=user.id, creator_handle=handle,
                          creator_name=name)
        db.add(existing)
        await db.commit()
        await db.refresh(existing)
    return {"ok": True, "following": _to_dict(existing)}


@router.delete("/following/{creator_handle}")
async def unfollow(creator_handle: str,
                   user: User = Depends(get_current_user),
                   db: AsyncSession = Depends(get_db)) -> dict:
    """Unfollow a creator. Idempotent: unknown handles still return ok."""
    handle = _normalize(creator_handle)
    existing = (await db.execute(
        select(Follow).where(Follow.user_id == user.id,
                             Follow.creator_handle == handle)
    )).scalar_one_or_none()
    if existing is not None:
        await db.delete(existing)
        await db.commit()
    return {"ok": True}


@router.get("/following")
async def list_following(user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)) -> dict:
    rows = (await db.execute(
        select(Follow).where(Follow.user_id == user.id)
        .order_by(Follow.created_at.desc())
    )).scalars().all()
    return {"following": [_to_dict(f) for f in rows]}
