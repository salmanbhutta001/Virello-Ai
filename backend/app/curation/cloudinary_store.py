"""Cloudinary image store for product galleries.

New gallery images are uploaded to Cloudinary (free tier) instead of being
committed to the GitHub repo — this keeps the repo under GitHub's 1GB
recommendation while the catalog keeps growing. Existing /gallery/* images
already in the repo keep serving as before; only NEW uploads go here.

Auth: VIRELLO_CLOUDINARY_URL (full cloudinary://key:secret@cloud URL).
Empty/malformed -> uploads disabled (callers must skip the product —
gallery-first rule: never list half-ready).

Security: the URL/secret NEVER appears in logs, exceptions, or return
values. Signed uploads only (SHA-1 of sorted params + api_secret).
"""
from __future__ import annotations

import hashlib
import logging
import time
import urllib.parse

import httpx

log = logging.getLogger("virello.curation.cloudinary")

MASK = "***"
UPLOAD_TIMEOUT = 60.0


def _creds() -> tuple[str, str, str] | None:
    """(cloud_name, api_key, api_secret) or None when not configured."""
    from app.core.config import settings

    raw = (settings.cloudinary_url or "").strip()
    if not raw:
        return None
    try:
        p = urllib.parse.urlparse(raw)
        if p.scheme != "cloudinary" or not p.hostname or not p.username:
            return None
        secret = urllib.parse.unquote(p.password or "")
        if not secret:
            return None
        return p.hostname, urllib.parse.unquote(p.username), secret
    except Exception:
        return None


def cloudinary_enabled() -> bool:
    return _creds() is not None


def _sign(params: dict[str, str], api_secret: str) -> str:
    body = "&".join(f"{k}={params[k]}" for k in sorted(params))
    return hashlib.sha1((body + api_secret).encode()).hexdigest()


async def upload_image(data: bytes, public_id: str,
                       *, folder: str = "virello/gallery") -> str:
    """Upload JPEG bytes to Cloudinary. Returns the secure_url.

    Raises RuntimeError on any failure (message never contains credentials).
    public_id should be like "<ASIN>_main" / "<ASIN>_angle2".
    """
    creds = _creds()
    if creds is None:
        raise RuntimeError("cloudinary not configured (VIRELLO_CLOUDINARY_URL)")
    cloud_name, api_key, api_secret = creds

    ts = str(int(time.time()))
    # Signature MUST cover exactly the parameters sent in the form
    # (minus file/api_key/signature) — any extra/missing param -> 401.
    form_params = {"public_id": public_id, "timestamp": ts,
                   "folder": folder, "overwrite": "true"}
    signature = _sign(form_params, api_secret)

    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
    files = {"file": ("image.jpg", data, "image/jpeg")}
    form = {"api_key": api_key, "signature": signature, **form_params}
    try:
        async with httpx.AsyncClient(timeout=UPLOAD_TIMEOUT) as client:
            r = await client.post(url, data=form, files=files)
    except Exception as e:
        raise RuntimeError(
            f"cloudinary upload transport failed: {type(e).__name__}") from None
    if r.status_code >= 400:
        try:
            detail = r.json()
        except Exception:
            detail = (r.text or "")[:300]
        # Cloudinary returns {"error": {"message": "..."}} — surface the
        # message (never credentials) so 401 causes are diagnosable.
        msg = (detail.get("error", {}).get("message")
               if isinstance(detail, dict) else detail)
        raise RuntimeError(
            f"cloudinary upload rejected (http {r.status_code}): {msg}")
    try:
        secure_url = r.json().get("secure_url", "")
    except Exception:
        secure_url = ""
    if not secure_url:
        raise RuntimeError("cloudinary upload: no secure_url in response")
    log.info("cloudinary upload ok: %s (%d bytes)", public_id, len(data))
    return secure_url


async def delete_image(public_id: str,
                       *, folder: str = "virello/gallery") -> bool:
    """Best-effort delete (admin cleanup). Never raises."""
    creds = _creds()
    if creds is None:
        return False
    cloud_name, api_key, api_secret = creds
    ts = str(int(time.time()))
    full_id = f"{folder}/{public_id}" if folder else public_id
    signature = _sign({"public_id": full_id, "timestamp": ts}, api_secret)
    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/destroy"
    try:
        async with httpx.AsyncClient(timeout=UPLOAD_TIMEOUT) as client:
            r = await client.post(url, data={
                "api_key": api_key, "timestamp": ts,
                "public_id": full_id, "signature": signature})
        return r.status_code < 400 and \
            r.json().get("result") in ("ok", "not found")
    except Exception:
        return False
