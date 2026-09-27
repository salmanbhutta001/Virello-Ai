from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.billing import Broadcast
from app.models.core import User
from app.services import language as lang_svc

router = APIRouter()


@router.get("/me")
async def me(user: User = Depends(get_current_user)) -> dict:
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
    }


@router.patch("/me")
async def update_me(payload: dict, user: User = Depends(get_current_user),
                    db: AsyncSession = Depends(get_db)) -> dict:
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
    return {"updated": True}


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
