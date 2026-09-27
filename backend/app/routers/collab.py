"""Creator Collab Match API — free organic growth strategy #4.

Creators opt in to a public matching pool; link owners find them by topic
overlap and send collab requests. The creator accepts/declines; after an
accept, the owner can mark the request "shared" once the creator has
genuinely shared the post. No fake share tracking anywhere.
"""
from __future__ import annotations

from datetime import datetime, timezone
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.collab import CollabRequest, CreatorProfile
from app.models.core import User

router = APIRouter()

_MAX_TOPICS = 12
_MAX_PLATFORMS = 8


def _norm_list(values: list[str], limit: int) -> list[str]:
    seen: list[str] = []
    for v in values:
        s = (v or "").strip().lower()
        if s and s not in seen:
            seen.append(s)
        if len(seen) >= limit:
            break
    return seen


def _profile_dict(p: CreatorProfile) -> dict:
    return {
        "creator_id": p.id,
        "user_id": str(p.user_id),
        "display_name": p.display_name,
        "topics": list(p.topics or []),
        "platforms": list(p.platforms or []),
        # Always labeled self-declared — never "verified".
        "audience_size": p.audience_size,
        "audience_size_label": "self-declared",
        "bio": p.bio or "",
        "is_opted_in": p.is_opted_in,
    }


class ProfileIn(BaseModel):
    display_name: str
    topics: list[str] = []
    platforms: list[str] = []
    audience_size: int | None = None
    bio: str | None = None
    is_opted_in: bool = True


async def _my_profile(db: AsyncSession, user: User) -> CreatorProfile | None:
    return (await db.execute(
        select(CreatorProfile).where(CreatorProfile.user_id == user.id)
    )).scalar_one_or_none()


@router.post("/profile")
async def upsert_profile(body: ProfileIn,
                         db: AsyncSession = Depends(get_db),
                         user: User = Depends(get_current_user)) -> dict:
    """Create or update my creator profile (opt-in / opt-out)."""
    name = (body.display_name or "").strip()
    if not name:
        raise HTTPException(400, "display_name is required")
    if body.audience_size is not None and body.audience_size < 0:
        raise HTTPException(400, "audience_size cannot be negative")
    topics = _norm_list(body.topics, _MAX_TOPICS)
    platforms = _norm_list(body.platforms, _MAX_PLATFORMS)

    profile = await _my_profile(db, user)
    if profile is None:
        profile = CreatorProfile(
            user_id=user.id, display_name=name[:120], topics=topics,
            platforms=platforms, audience_size=body.audience_size,
            bio=(body.bio or "").strip()[:2000] or None,
            is_opted_in=body.is_opted_in)
        db.add(profile)
    else:
        profile.display_name = name[:120]
        profile.topics = topics
        profile.platforms = platforms
        profile.audience_size = body.audience_size
        profile.bio = (body.bio or "").strip()[:2000] or None
        profile.is_opted_in = body.is_opted_in
    await db.commit()
    await db.refresh(profile)
    return {"profile": _profile_dict(profile)}


@router.get("/profile")
async def get_profile(db: AsyncSession = Depends(get_db),
                      user: User = Depends(get_current_user)) -> dict:
    profile = await _my_profile(db, user)
    return {"profile": _profile_dict(profile) if profile else None}


class MatchIn(BaseModel):
    topics: list[str] = []
    min_audience: int | None = None
    platforms: list[str] = []


@router.post("/match")
async def match_creators(body: MatchIn,
                         db: AsyncSession = Depends(get_db),
                         user: User = Depends(get_current_user)) -> dict:
    """Rank opted-in creators by topic overlap.

    topic_fit = |requested topics ∩ creator topics| / |requested topics|.
    Only an overlap score — it promises nothing about outcomes.
    """
    wanted = _norm_list(body.topics, _MAX_TOPICS)
    want_platforms = set(_norm_list(body.platforms, _MAX_PLATFORMS))

    rows = (await db.execute(
        select(CreatorProfile).where(CreatorProfile.is_opted_in.is_(True))
    )).scalars().all()

    matches: list[dict] = []
    for p in rows:
        ptopics = set((p.topics or []))
        overlap = sorted(set(wanted) & ptopics)
        topic_fit = (len(overlap) / len(wanted)) if wanted else 0.0
        pplats = set(p.platforms or [])
        if want_platforms and not (want_platforms & pplats):
            continue  # no shared platform: skip
        if (body.min_audience is not None and
                (p.audience_size is None or
                 p.audience_size < body.min_audience)):
            continue  # below the self-declared minimum: skip
        d = _profile_dict(p)
        d["topic_fit"] = round(topic_fit, 3)
        d["matched_topics"] = overlap
        matches.append(d)

    matches.sort(
        key=lambda m: (m["topic_fit"], m["audience_size"] or 0),
        reverse=True)

    return {
        "matches": matches,
        "count": len(matches),
        "scoring": {
            "metric": "topic_fit",
            "formula": "matched_topics / requested_topics",
            "note": ("topic_fit is a simple topic-overlap score. "
                     "It does not predict reach, views, or any outcome."),
        },
        # Reminder, every response: these numbers are the creators' own
        # claims, not independently verified measurements.
        "audience_note": "All audience_size values are self-declared.",
    }


class RequestIn(BaseModel):
    creator_id: str
    post_url: str
    message: str | None = None


def _request_dict(r: CollabRequest,
                  creator_name: str | None = None) -> dict:
    return {
        "request_id": r.id,
        "link_owner_id": str(r.link_owner_id),
        "creator_id": r.creator_id,
        "creator_name": creator_name or "",
        "post_url": r.post_url,
        "message": r.message or "",
        "status": r.status,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "decided_at": r.decided_at.isoformat() if r.decided_at else None,
    }


@router.post("/request")
async def send_request(body: RequestIn,
                       db: AsyncSession = Depends(get_db),
                       user: User = Depends(get_current_user)) -> dict:
    """Link owner sends a collab request to an opted-in creator."""
    creator = (await db.execute(
        select(CreatorProfile).where(
            CreatorProfile.id == body.creator_id,
            CreatorProfile.is_opted_in.is_(True))
    )).scalar_one_or_none()
    if creator is None:
        raise HTTPException(
            404, "Creator not found or not accepting collabs")
    if creator.user_id == user.id:
        raise HTTPException(400, "You can't send a collab request to yourself")

    raw = (body.post_url or "").strip()
    parsed = urlparse(raw)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise HTTPException(
            422, "post_url must be a full http(s) link to your post")

    dupe = (await db.execute(
        select(CollabRequest).where(
            CollabRequest.link_owner_id == user.id,
            CollabRequest.creator_id == creator.id,
            CollabRequest.post_url == raw,
            CollabRequest.status == CollabRequest.PENDING)
    )).scalar_one_or_none()
    if dupe is not None:
        raise HTTPException(
            409, "You already have a pending request to this creator "
                 "for the same post")

    req = CollabRequest(
        link_owner_id=user.id, creator_id=creator.id, post_url=raw,
        message=(body.message or "").strip()[:1000] or None,
        status=CollabRequest.PENDING)
    db.add(req)
    await db.commit()
    await db.refresh(req)
    return {"request": _request_dict(req, creator.display_name)}


@router.get("/inbox")
async def inbox(db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    """Incoming requests for MY creator profile only."""
    profile = await _my_profile(db, user)
    if profile is None:
        return {"requests": []}
    rows = (await db.execute(
        select(CollabRequest, User)
        .join(User, User.id == CollabRequest.link_owner_id)
        .where(CollabRequest.creator_id == profile.id)
        .order_by(CollabRequest.created_at.desc())
    )).all()
    return {"requests": [
        {**_request_dict(r), "owner_name": u.name or u.email}
        for r, u in rows]}


@router.get("/requests/mine")
async def outbox(db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    """Requests I (as a link owner) have sent."""
    rows = (await db.execute(
        select(CollabRequest, CreatorProfile)
        .join(CreatorProfile, CreatorProfile.id == CollabRequest.creator_id)
        .where(CollabRequest.link_owner_id == user.id)
        .order_by(CollabRequest.created_at.desc())
    )).all()
    return {"requests": [
        _request_dict(r, p.display_name) for r, p in rows]}


class DecideIn(BaseModel):
    action: str  # accept | decline | mark_shared


@router.patch("/requests/{request_id}")
async def decide_request(request_id: str, body: DecideIn,
                         db: AsyncSession = Depends(get_db),
                         user: User = Depends(get_current_user)) -> dict:
    """State transitions — only by the involved parties' own actions.

    - accept / decline: the creator (profile owner), from pending.
    - mark_shared: the link owner, from accepted, after the creator has
      genuinely shared the post. No automated share detection exists;
      this status is the owner's own confirmation.
    """
    action = (body.action or "").strip().lower()
    if action not in ("accept", "decline", "mark_shared"):
        raise HTTPException(
            400, "action must be accept, decline, or mark_shared")

    req = (await db.execute(
        select(CollabRequest).where(CollabRequest.id == request_id)
    )).scalar_one_or_none()
    if req is None:
        raise HTTPException(404, "Request not found")

    profile = await _my_profile(db, user)
    is_creator = profile is not None and profile.id == req.creator_id
    is_owner = req.link_owner_id == user.id
    now = datetime.now(timezone.utc)

    if action in ("accept", "decline"):
        if not is_creator:
            raise HTTPException(
                403, "Only the creator can accept or decline this request")
        if req.status != CollabRequest.PENDING:
            raise HTTPException(
                409, f"Cannot {action} a request that is {req.status}")
        req.status = (CollabRequest.ACCEPTED if action == "accept"
                      else CollabRequest.DECLINED)
        req.decided_at = now
    else:  # mark_shared
        if not is_owner:
            raise HTTPException(
                403, "Only the link owner can mark a request as shared")
        if req.status != CollabRequest.ACCEPTED:
            raise HTTPException(
                409, "Only an accepted request can be marked as shared — "
                     "the creator must accept first, then genuinely share")
        req.status = CollabRequest.SHARED

    await db.commit()
    await db.refresh(req)
    return {"request": _request_dict(req)}
