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
from app.models.social import Follow, PostComment

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


# ------------------------------ comments ------------------------------
# Genuine user comments on discovery posts (board screen 15).
# Keyed by post URL: discovery items are external posts with no local row.
# Comments are only ever created by the authenticated user's explicit
# action — never seeded, never fabricated. The author's display name is
# snapshotted from their profile (name, else email prefix); raw emails
# are never exposed to other users.

class CommentIn(BaseModel):
    post_url: str
    text: str


def _author_name(user: User) -> str:
    name = (user.name or "").strip()
    if name:
        return name
    return user.email.split("@")[0]


def _comment_to_dict(c: PostComment, viewer_id) -> dict:
    return {
        "id": c.id,
        "post_url": c.post_url,
        "text": c.text,
        "author_name": c.author_name,
        "mine": str(c.user_id) == str(viewer_id),
        "created_at": c.created_at.isoformat() if c.created_at else None,
    }


@router.get("/comments")
async def list_comments(post_url: str,
                        user: User = Depends(get_current_user),
                        db: AsyncSession = Depends(get_db)) -> dict:
    """Real comments on one post, newest first. Empty list when none —
    never fabricated."""
    url = post_url.strip()
    if not url:
        raise HTTPException(400, "post_url must not be empty")
    rows = (await db.execute(
        select(PostComment).where(PostComment.post_url == url)
        .order_by(PostComment.created_at.desc())
        .limit(200)
    )).scalars().all()
    return {"comments": [_comment_to_dict(c, user.id) for c in rows]}


@router.get("/comments/mine")
async def my_comments(user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)) -> dict:
    """The authenticated user's own comments, newest first. Powers the
    Activity screen's Comments tab with real data only."""
    rows = (await db.execute(
        select(PostComment).where(PostComment.user_id == user.id)
        .order_by(PostComment.created_at.desc())
        .limit(200)
    )).scalars().all()
    return {"comments": [_comment_to_dict(c, user.id) for c in rows]}


@router.post("/comments", status_code=201)
async def post_comment(body: CommentIn,
                       user: User = Depends(get_current_user),
                       db: AsyncSession = Depends(get_db)) -> dict:
    text = body.text.strip()
    url = body.post_url.strip()
    if not url:
        raise HTTPException(400, "post_url must not be empty")
    if not text:
        raise HTTPException(422, "Comment text must not be empty")
    if len(text) > 2000:
        raise HTTPException(422, "Comment is too long (max 2000 characters)")
    comment = PostComment(user_id=user.id, post_url=url, text=text,
                          author_name=_author_name(user))
    db.add(comment)
    await db.commit()
    await db.refresh(comment)
    return {"ok": True, "comment": _comment_to_dict(comment, user.id)}


@router.delete("/comments/{comment_id}")
async def delete_comment(comment_id: str,
                         user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)) -> dict:
    """Delete your own comment. Deleting someone else's is forbidden."""
    comment = (await db.execute(
        select(PostComment).where(PostComment.id == comment_id)
    )).scalar_one_or_none()
    if comment is None:
        raise HTTPException(404, "Comment not found")
    if str(comment.user_id) != str(user.id):
        raise HTTPException(403, "You can only delete your own comments")
    await db.delete(comment)
    await db.commit()
    return {"ok": True}
