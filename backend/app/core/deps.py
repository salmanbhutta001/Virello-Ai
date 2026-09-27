"""FastAPI dependencies: DB session + current user (JWT, with dev bypass)."""
import uuid

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import decode_token
from app.models.core import User

_bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> User:
    if settings.dev_noauth:
        # DEV ONLY — never enable in production.
        res = await db.execute(select(User).where(User.email == "dev@virello.app"))
        user = res.scalar_one_or_none()
        if user is None:
            user = User(email="dev@virello.app", name="Dev", locale="en")
            db.add(user)
            await db.commit()
            await db.refresh(user)
        return user

    if creds is None:
        raise HTTPException(401, "Missing bearer token")
    try:
        user_id = decode_token(creds.credentials)
    except ValueError as e:
        raise HTTPException(401, str(e))
    res = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = res.scalar_one_or_none()
    if user is None:
        raise HTTPException(401, "User not found")
    return user
