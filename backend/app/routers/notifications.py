"""Personal in-app notifications (withdrawal approved / paid, …).

Separate from the admin broadcast feed (GET /users/notifications).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.services import wallet as wallet_svc

router = APIRouter()


@router.get("")
async def my_notifications(user: User = Depends(get_current_user),
                           db: AsyncSession = Depends(get_db)) -> dict:
    return {"notifications": await wallet_svc.list_notifications(
        db, user.id)}


@router.post("/{notification_id}/read")
async def mark_read(notification_id: str,
                    user: User = Depends(get_current_user),
                    db: AsyncSession = Depends(get_db)) -> dict:
    try:
        nid = uuid.UUID(notification_id)
    except ValueError:
        raise HTTPException(404, "Not found")
    ok = await wallet_svc.mark_notification_read(db, user.id, nid)
    if not ok:
        raise HTTPException(404, "Not found")
    return {"ok": True}
