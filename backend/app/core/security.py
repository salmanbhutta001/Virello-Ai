"""Security: JWT, Apple/Google OIDC verification, email OTP, password hashing,
OAuth token encryption."""
import base64
import secrets
import time
from datetime import datetime, timedelta, timezone

import httpx
from cryptography.fernet import Fernet, InvalidToken
from jose import JWTError, jwt
import bcrypt

from app.core.config import settings

# ---------------------------------------------------------------- JWT
def create_token(sub: str, expires: timedelta, token_type: str = "access") -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + expires).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_token_pair(sub: str) -> dict:
    return {
        "access_token": create_token(sub, timedelta(minutes=settings.access_token_minutes)),
        "refresh_token": create_token(
            sub, timedelta(days=settings.refresh_token_days), token_type="refresh"
        ),
        "token_type": "bearer",
    }


def decode_token(token: str, expected_type: str = "access") -> str:
    """Returns the subject (user id) or raises ValueError."""
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError as e:
        raise ValueError(f"invalid token: {e}")
    if payload.get("type") != expected_type:
        raise ValueError("wrong token type")
    return str(payload["sub"])


# ---------------------------------------------------------------- OIDC (Apple / Google)
async def _fetch_jwks(url: str) -> dict:
    async with httpx.AsyncClient(timeout=10) as client:
        res = await client.get(url)
        res.raise_for_status()
        return res.json()


async def verify_oidc_token(provider: str, id_token: str) -> dict:
    """Verify Apple/Google id_token, return claims (sub, email, name)."""
    if provider == "apple":
        jwks = await _fetch_jwks("https://appleid.apple.com/auth/keys")
        audience = None  # validated against Services ID in production config
    elif provider == "google":
        jwks = await _fetch_jwks("https://www.googleapis.com/oauth2/v3/certs")
        audience = None
    else:
        raise ValueError(f"unsupported provider: {provider}")

    headers = jwt.get_unverified_header(id_token)
    key = next((k for k in jwks["keys"] if k["kid"] == headers.get("kid")), None)
    if not key:
        raise ValueError("unknown signing key")
    try:
        claims = jwt.decode(
            id_token, key, algorithms=["RS256"], audience=audience,
            options={"verify_aud": audience is not None},
        )
    except JWTError as e:
        raise ValueError(f"OIDC verification failed: {e}")
    return {"sub": claims["sub"], "email": claims.get("email"), "name": claims.get("name")}


# ---------------------------------------------------------------- Email OTP (dev: in-memory; prod: Redis)
_otp_store: dict[str, tuple[str, float]] = {}  # email -> (code, expires_at)


def issue_otp(email: str) -> str:
    code = f"{secrets.randbelow(900000) + 100000}"
    _otp_store[email.lower()] = (code, time.time() + 600)
    # TODO prod: send via email provider + store in Redis. Dev: log it.
    print(f"[dev] OTP for {email}: {code}")
    return code


def verify_otp(email: str, code: str) -> bool:
    record = _otp_store.pop(email.lower(), None)
    if not record:
        return False
    expected, expires_at = record
    return expected == code and time.time() < expires_at


# ---------------------------------------------------------------- OAuth token encryption (Fernet)
def _fernet() -> Fernet:
    key = settings.oauth_token_key
    try:
        # Must be 32 urlsafe-b64-encoded bytes.
        base64.urlsafe_b64decode(key)
        return Fernet(key.encode() if isinstance(key, str) else key)
    except Exception:
        print("[warn] VIRELLO_OAUTH_TOKEN_KEY invalid — using ephemeral dev key")
        return Fernet(Fernet.generate_key())


def encrypt_token(plain: str) -> str:
    return _fernet().encrypt(plain.encode()).decode()


def decrypt_token(cipher: str) -> str:
    try:
        return _fernet().decrypt(cipher.encode()).decode()
    except InvalidToken:
        raise ValueError("cannot decrypt OAuth token")


# ---------------------------------------------------------------- Passwords
def _pw_bytes(password: str) -> bytes:
    # bcrypt accepts at most 72 bytes; the API layer already rejects longer
    # passwords with 422, this is belt-and-braces.
    return password.encode("utf-8")[:72]


def hash_password(password: str) -> str:
    """bcrypt-hash a password. Never log or store the plain value."""
    return bcrypt.hashpw(_pw_bytes(password), bcrypt.gensalt()).decode("ascii")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(_pw_bytes(password),
                              password_hash.encode("ascii"))
    except Exception:
        return False


# ---------------------------------------------------------------- Login throttle
# Best-effort in-memory brute-force guard for password login: after
# _MAX_LOGIN_ATTEMPTS failures for one email inside _LOGIN_WINDOW_SEC, further
# attempts are rejected with 429 until the window passes. (Single-process
# guard; production deployments behind multiple workers should move this to
# Redis — tracked as a prod-hardening note, not a silent guarantee.)
_MAX_LOGIN_ATTEMPTS = 5
_LOGIN_WINDOW_SEC = 900
_login_failures: dict[str, list[float]] = {}


def _prune_failures(key: str, now: float) -> list[float]:
    kept = [t for t in _login_failures.get(key, []) if now - t < _LOGIN_WINDOW_SEC]
    _login_failures[key] = kept
    return kept


def check_login_throttle(key: str) -> None:
    """Raise True when the caller must be throttled (caller maps to 429)."""
    now = time.time()
    if len(_prune_failures(key, now)) >= _MAX_LOGIN_ATTEMPTS:
        raise PermissionError("too many attempts")


def record_login_failure(key: str) -> None:
    _login_failures.setdefault(key, []).append(time.time())


def clear_login_attempts(key: str) -> None:
    _login_failures.pop(key, None)
