from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.billing import Broadcast
from app.models.core import User
from app.services import language as lang_svc
from app.services import rewards as rewards_svc
from app.services import wallet as wallet_svc

router = APIRouter()


@router.get("/search")
async def search_users(
    q: str = Query(default="", max_length=120),
    limit: int = Query(default=20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """Search users by display name — case-insensitive, partial,
    typo-tolerant, relevance-ranked. Suspended accounts excluded.
    Only real matches; never invents users."""
    from app.services.search import normalize_query, search_users as _search
    query = normalize_query(q)
    if not query:
        return {"users": [], "query": "", "total": 0}
    users = await _search(db, query, limit=limit)
    return {"users": users, "query": query, "total": len(users)}


@router.get("/me")
async def me(user: User = Depends(get_current_user),
             db: AsyncSession = Depends(get_db)) -> dict:
    # Daily login points: idempotent per day, never breaks the profile read.
    try:
        login_pts = await rewards_svc.award_daily_login(db, user.id)
    except Exception:
        login_pts = 0
    bal = await rewards_svc.get_balance(db, user.id)
    cash_cents = await wallet_svc.cash_balance(db, user.id)
    return {
        "id": str(user.id),
        "email": user.email,
        "name": user.name,
        "plan": user.plan.value,
        "credits": user.credits,
        "locale": user.locale,
        "preferred_language": user.preferred_language or "en",
        "content_languages": list(user.content_languages or []),
        "all_relevant_languages": bool(user.all_relevant_languages),
        "is_admin": user.is_admin,
        "suspended": user.suspended,
        "email_verified": bool(user.email_verified),
        "profile_completed": wallet_svc.profile_is_completed(user),
        "points_balance": bal["balance"],
        "points_level": bal["level"],
        "daily_login_points": login_pts,
        "cash_balance_cents": cash_cents,
        "cash_display": wallet_svc.fmt_cents(cash_cents),
    }


@router.patch("/me")
async def update_me(payload: dict, user: User = Depends(get_current_user),
                    db: AsyncSession = Depends(get_db)) -> dict:
    was_complete = wallet_svc.profile_is_completed(user)
    if "name" in payload and payload["name"]:
        user.name = str(payload["name"])[:255]
    if "locale" in payload and payload["locale"] in ("en", "ur", "ar"):
        user.locale = payload["locale"]
    if "preferred_language" in payload:
        code = str(payload["preferred_language"]).strip().lower()
        if not lang_svc.is_supported(code):
            raise HTTPException(400, f"Unsupported language: {code}.")
        user.preferred_language = code
    if "content_languages" in payload:
        langs = [str(c).strip().lower()
                 for c in (payload["content_languages"] or [])][:8]
        for code in langs:
            if not lang_svc.is_supported(code):
                raise HTTPException(400, f"Unsupported language: {code}.")
        user.content_languages = langs
    if "all_relevant_languages" in payload:
        user.all_relevant_languages = bool(
            payload["all_relevant_languages"])
    await db.commit()
    # Profile-completed points: +20 once, when the profile newly counts as
    # completed (a real display name set). Never breaks the update.
    profile_pts = 0
    if not was_complete and wallet_svc.profile_is_completed(user):
        try:
            profile_pts = await rewards_svc.award_profile_completed(
                db, user.id, user.name, user.preferred_language)
        except Exception:
            profile_pts = 0
    return {"updated": True, "profile_points": profile_pts}


@router.get("/notifications")
async def my_notifications(user: User = Depends(get_current_user),
                           db: AsyncSession = Depends(get_db)) -> dict:
    """Broadcasts visible to this user, localized to their preferred
    language when the admin supplied a translation. Falls back to the
    base language with fallback_used=true — never silently substituted.
    """
    plan = (user.plan or "free").lower()
    rows = (await db.execute(
        select(Broadcast).order_by(desc(Broadcast.created_at)).limit(50)
    )).scalars().all()
    lang = (user.preferred_language or user.locale or "en").strip().lower()
    items = []
    for b in rows:
        if b.audience == "all":
            visible = True
        elif b.audience == "free":
            visible = plan in ("free", "")
        elif b.audience == "paid":
            visible = plan not in ("free", "")
        else:
            visible = True
        if not visible:
            continue
        translations = b.translations or {}
        tpl = translations.get(lang)
        if tpl:
            title, body, fallback = tpl["title"], tpl["body"], False
        else:
            title, body, fallback = b.title, b.body, True
        items.append({
            "id": str(b.id),
            "title": title,
            "body": body,
            "audience": b.audience,
            "language_requested": lang,
            "fallback_used": fallback,
            "created_at": b.created_at.isoformat(),
        })
    return {"notifications": items}
