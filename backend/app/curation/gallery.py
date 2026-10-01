"""Gallery-first image pipeline.

For each product: download the REAL main photo, then generate 2 alternate
angles conditioned on that real photo via the keyless Pollinations image
API (img2img). Generation is NEVER title-only — the reference is always
the real product photo.

NEW images are uploaded to Cloudinary (free tier) — never committed to the
GitHub repo (repo-size rule, Hafiz 2026-10-01). Cloudinary URLs are live
immediately, no deploy needed. Existing /gallery/* repo images keep
serving as before.

Automated checks verify file integrity (valid JPEG, sane dimensions and
size) only. They cannot confirm the generated angle actually depicts the
same product — human review of new listings is recommended; the admin
status endpoint flags every auto-listed product's gallery for review.
"""
from __future__ import annotations

import io
import logging
import random
import urllib.parse

import httpx
from PIL import Image

from app.curation import config
from app.curation.cloudinary_store import cloudinary_enabled, upload_image

log = logging.getLogger("virello.curation.gallery")

MIN_JPEG_BYTES = 10_000
MAX_JPEG_BYTES = 15_000_000
MIN_DIMENSION = 384

ANGLE_PROMPTS = [
    ("side angle",
     "side three-quarter angle view of this exact same product"),
    ("detail / lifestyle",
     "close-up detail view showing texture and design of this exact same "
     "product, styled product photography"),
]


async def download_bytes(url: str, timeout: float = 30.0) -> bytes:
    headers = {"User-Agent": config.BROWSER_UA}
    async with httpx.AsyncClient(timeout=timeout,
                                 follow_redirects=True) as client:
        r = await client.get(url, headers=headers)
        r.raise_for_status()
        return r.content


def check_jpeg(data: bytes) -> tuple[bool, str]:
    """Integrity check only — magic bytes, size bounds, PIL decode,
    minimum dimensions. Says nothing about visual fidelity."""
    if len(data) < MIN_JPEG_BYTES:
        return False, f"too small ({len(data)} bytes)"
    if len(data) > MAX_JPEG_BYTES:
        return False, f"too large ({len(data)} bytes)"
    if not data.startswith(b"\xff\xd8\xff"):
        return False, "not a JPEG (bad magic)"
    try:
        with Image.open(io.BytesIO(data)) as im:
            im.verify()
        with Image.open(io.BytesIO(data)) as im:
            w, h = im.size
    except Exception as e:
        return False, f"PIL decode failed: {type(e).__name__}"
    if min(w, h) < MIN_DIMENSION:
        return False, f"dimensions too small ({w}x{h})"
    return True, f"ok ({w}x{h}, {len(data)} bytes)"


def _pollinations_url(prompt: str, reference_url: str, seed: int) -> str:
    q = urllib.parse.quote
    return (
        "https://image.pollinations.ai/prompt/" + q(prompt)
        + "?image=" + q(reference_url, safe="")
        + "&model=flux&width=1024&height=1024&nologo=true"
        + f"&seed={seed}"
    )


async def _generate_angle(reference_url: str, angle_desc: str,
                          timeout: float = 150.0) -> bytes:
    prompt = (
        "Product photo of this exact same product — identical colors, "
        "identical design, identical branding and proportions, nothing "
        "added or removed. " + angle_desc + ". Clean pure-white background, "
        "professional studio product photography, sharp, high detail."
    )
    url = _pollinations_url(prompt, reference_url,
                            seed=random.randint(1, 999_999_999))
    return await download_bytes(url, timeout=timeout)


async def build_gallery(asin: str, main_image_url: str,
                        public_base: str | None = None) -> dict:
    """Build the 3-image gallery. Returns dict:
    {ok, image_urls[3], real, generated, notes[]}.

    ok=False when the gallery is incomplete — the orchestrator must SKIP
    the product then (gallery-first rule), never list it half-ready.

    Images go to Cloudinary; the returned URLs are live immediately.
    """
    asin = asin.strip().upper()
    notes: list[str] = []
    image_urls: list[str] = []

    if not cloudinary_enabled():
        return {"ok": False, "image_urls": [],
                "notes": ["cloudinary not configured "
                          "(VIRELLO_CLOUDINARY_URL) — gallery skipped"]}

    async def _store(data: bytes, public_id: str) -> str | None:
        try:
            return await upload_image(data, public_id)
        except Exception as e:
            notes.append(f"cloudinary upload failed for {public_id}: {e}")
            return None

    # 1) Real main photo → image #1.
    try:
        raw = await download_bytes(main_image_url)
    except Exception as e:
        return {"ok": False, "image_urls": [],
                "notes": [f"main photo download failed: {type(e).__name__}"]}
    ok, why = check_jpeg(raw)
    if not ok:
        return {"ok": False, "image_urls": [],
                "notes": [f"main photo invalid: {why}"]}
    url = await _store(raw, f"{asin}_main")
    if not url:
        return {"ok": False, "image_urls": [], "notes": notes}
    image_urls.append(url)
    notes.append(f"main photo real ({why}) → cloudinary")

    # 2) Two generated angles, always conditioned on the real photo.
    generated = 0
    for i, (angle_name, angle_desc) in enumerate(ANGLE_PROMPTS, start=2):
        try:
            gen = await _generate_angle(main_image_url, angle_desc)
        except Exception as e:
            notes.append(f"angle{i} ({angle_name}) generation failed: "
                         f"{type(e).__name__}")
            continue
        ok, why = check_jpeg(gen)
        if not ok:
            notes.append(f"angle{i} ({angle_name}) failed check: {why}")
            continue
        url = await _store(gen, f"{asin}_angle{i}")
        if not url:
            continue
        image_urls.append(url)
        generated += 1
        notes.append(f"angle{i} ({angle_name}) generated ({why}) → cloudinary")

    if len(image_urls) < 3:
        return {"ok": False, "image_urls": image_urls, "notes": notes}
    notes.append("auto-integrity-check only — visual fidelity not verified; "
                 "flagged for admin review")
    return {"ok": True, "image_urls": image_urls, "real": 1,
            "generated": generated, "notes": notes}
