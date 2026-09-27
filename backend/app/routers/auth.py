"""Auth: Apple/Google OIDC + email OTP + email/password. Issues Virello JWT pair.

Password rules: bcrypt-hashed, never logged; 8..72 chars. Login is
throttled per email (5 failures / 15 min -> 429). Password reset reuses the
email-OTP channel to prove ownership before a new password is set.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.security import (
    check_login_throttle,
    clear_login_attempts,
    create_token_pair,
    hash_password,
    issue_otp,
    record_login_failure,
    verify_oidc_token,
    verify_otp,
    verify_password,
)
from app.models.core import User, UserActivity
from app.routers.referrals import award_referral_credits, record_referral_signup

router = APIRouter()


class OAuthCallbackIn(BaseModel):
    id_token: str


class OtpRequestIn(BaseModel):
    email: EmailStr


class OtpVerifyIn(BaseModel):
    email: EmailStr
    code: str
    referral_code: str | None = None  # optional: referrer's code


class RefreshIn(BaseModel):
    refresh_token: str


async def _upsert_user(db: AsyncSession, email: str | None, name: str | None,
                      provider: str, provider_sub: str) -> User:
    res = await db.execute(select(User).where(User.email == email)) if email else None
    user = res.scalar_one_or_none() if res else None
    if user is None:
        user = User(email=email or f"{provider_sub}@{provider}.local",
                    name=name or "Virello user", locale="en")
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return user


@router.post("/oauth/{provider}/callback")
async def oauth_callback(provider: str, body: OAuthCallbackIn,
                         db: AsyncSession = Depends(get_db)) -> dict:
    """Verify provider id_token via JWKS, upsert user, return JWT pair."""
    if provider not in ("apple", "google"):
        raise HTTPException(400, "Unsupported provider")
    try:
        claims = await verify_oidc_token(provider, body.id_token)
    except ValueError as e:
        raise HTTPException(401, str(e))
    user = await _upsert_user(db, claims.get("email"), claims.get("name"),
                              provider, claims["sub"])
    db.add(UserActivity(user_id=user.id, event="login"))
    await db.commit()
    return create_token_pair(str(user.id))


@router.post("/otp/request")
async def otp_request(body: OtpRequestIn) -> dict:
    issue_otp(body.email)
    return {"sent": True}


@router.post("/otp/verify")
async def otp_verify(body: OtpVerifyIn, db: AsyncSession = Depends(get_db)) -> dict:
    if not verify_otp(body.email, body.code):
        raise HTTPException(401, "Invalid or expired code")
    is_new_signup = await _find_user_ci(db, body.email) is None
    user = await _upsert_user(db, body.email, None, "email", body.email)
    if is_new_signup:
        # OTP verification == verified signup: record the referral and pay
        # out immediately. Invalid/self codes are ignored, never an error.
        await record_referral_signup(db, referral_code=body.referral_code,
                                     new_user=user)
        await award_referral_credits(db, user.id)
    db.add(UserActivity(user_id=user.id, event="login"))
    await db.commit()
    return create_token_pair(str(user.id))


@router.post("/refresh")
async def refresh(body: RefreshIn) -> dict:
    from app.core.security import decode_token
    try:
        sub = decode_token(body.refresh_token, expected_type="refresh")
    except ValueError as e:
        raise HTTPException(401, str(e))
    return create_token_pair(sub)


# ------------------------------------------------------- Email + password
class PasswordSignupIn(BaseModel):
    email: EmailStr
    password: str
    name: str | None = None
    referral_code: str | None = None  # optional: referrer's code


class PasswordLoginIn(BaseModel):
    email: EmailStr
    password: str


class PasswordResetRequestIn(BaseModel):
    email: EmailStr


class PasswordResetConfirmIn(BaseModel):
    email: EmailStr
    code: str
    new_password: str


def _validate_password(password: str) -> None:
    if len(password) < 8:
        raise HTTPException(422, "Password must be at least 8 characters")
    if len(password) > 72:  # bcrypt input limit
        raise HTTPException(422, "Password must be at most 72 characters")


async def _find_user_ci(db: AsyncSession, email: str) -> User | None:
    """Case-insensitive email lookup (OTP signups may vary in case)."""
    res = await db.execute(
        select(User).where(func.lower(User.email) == email.lower()))
    return res.scalar_one_or_none()


@router.post("/password/signup")
async def password_signup(body: PasswordSignupIn,
                          db: AsyncSession = Depends(get_db)) -> dict:
    """Create an account with email + password. Fails closed (409) when the
    email already exists — use sign-in or Forgot password (OTP-proved) to
    attach a password to an existing OTP/OAuth account instead."""
    _validate_password(body.password)
    email = body.email.strip().lower()
    if await _find_user_ci(db, email) is not None:
        raise HTTPException(
            409,
            "An account with this email already exists. Sign in instead, "
            "or use Forgot password to set a password for it.")
    user = User(email=email, name=(body.name or "Virello user").strip()[:255],
                locale="en", password_hash=hash_password(body.password),
                password_updated_at=datetime.now(timezone.utc))
    db.add(user)
    await db.commit()
    await db.refresh(user)
    # Password signup completes the account in one step, so it counts as a
    # verified signup for referrals: record the event and pay out. Invalid /
    # self codes are ignored, never an error.
    await record_referral_signup(db, referral_code=body.referral_code,
                                 new_user=user)
    await award_referral_credits(db, user.id)
    db.add(UserActivity(user_id=user.id, event="login"))
    await db.commit()
    return create_token_pair(str(user.id))


@router.post("/password/login")
async def password_login(body: PasswordLoginIn,
                         db: AsyncSession = Depends(get_db)) -> dict:
    """Email + password sign-in. Generic 401 on any mismatch (no enumeration);
    429 when the per-email throttle trips."""
    email = body.email.strip().lower()
    try:
        check_login_throttle(email)
    except PermissionError:
        raise HTTPException(429, "Too many attempts. Try again in a few minutes.")
    user = await _find_user_ci(db, email)
    ok = (user is not None and user.password_hash
          and verify_password(body.password, user.password_hash))
    if not ok:
        record_login_failure(email)
        raise HTTPException(401, "Invalid email or password")
    if user.suspended:
        raise HTTPException(403, "Account suspended")
    clear_login_attempts(email)
    db.add(UserActivity(user_id=user.id, event="login"))
    await db.commit()
    return create_token_pair(str(user.id))


@router.post("/password/reset/request")
async def password_reset_request(body: PasswordResetRequestIn) -> dict:
    """Send an OTP code to prove email ownership. Always 200 (no enumeration)."""
    issue_otp(body.email)
    return {"sent": True}


@router.post("/password/reset/confirm")
async def password_reset_confirm(body: PasswordResetConfirmIn,
                                 db: AsyncSession = Depends(get_db)) -> dict:
    """Verify the OTP code, then set the new password and sign the user in.
    Also lets OTP/OAuth accounts attach a password for the first time."""
    _validate_password(body.new_password)
    if not verify_otp(body.email, body.code):
        raise HTTPException(401, "Invalid or expired code")
    email = body.email.strip().lower()
    user = await _find_user_ci(db, email)
    if user is None:
        raise HTTPException(404, "No account with this email")
    user.password_hash = hash_password(body.new_password)
    user.password_updated_at = datetime.now(timezone.utc)
    clear_login_attempts(email)
    db.add(UserActivity(user_id=user.id, event="login"))
    await db.commit()
    return create_token_pair(str(user.id))


# ------------------------------------------------------- Change password
class PasswordChangeIn(BaseModel):
    current_password: str
    new_password: str


@router.post("/password/change")
async def password_change(body: PasswordChangeIn,
                          db: AsyncSession = Depends(get_db),
                          user: User = Depends(get_current_user)) -> dict:
    """Signed-in password change: prove the current password, set a new one."""
    _validate_password(body.new_password)
    if not user.password_hash or not verify_password(
            body.current_password, user.password_hash):
        raise HTTPException(401, "Current password is incorrect")
    user.password_hash = hash_password(body.new_password)
    user.password_updated_at = datetime.now(timezone.utc)
    clear_login_attempts(user.email.strip().lower())
    await db.commit()
    return {"changed": True}
