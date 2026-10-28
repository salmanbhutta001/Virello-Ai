"""Curation settings — all via VIRELLO_ env vars (see app/core/config.py).

Local dev defaults work out of the box. On Railway set:
  VIRELLO_GALLERY_DIR=/data/gallery        (Railway volume mount point)
  VIRELLO_CURATION_LOG_PATH=/data/curation_runs.log
  VIRELLO_CURATOR_CREATOR_EMAIL=<creator login email>
  VIRELLO_PUBLIC_BASE_URL=https://virello-api-production.up.railway.app
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

from app.models.commerce import PRODUCT_CATEGORIES

log = logging.getLogger("virello.curation.config")


def _ensure_dir(d: Path) -> Path:
    """mkdir that never raises: Vercel serverless /var/task is read-only,
    so creating app/static/... fails with OSError. Callers that only READ
    (gallery fallback) tolerate a missing dir; callers that WRITE fall
    back to /tmp via their own logic. Never let a mkdir kill a request
    (or, at import time, the whole app)."""
    try:
        d.mkdir(parents=True, exist_ok=True)
    except OSError:
        log.warning("cannot create dir %s (read-only fs?) — continuing", d)
    return d

# UI-only slugs — merchandising/filter concepts, not departments.
UI_FILTER_SLUGS = {"all", "men", "women", "sale", "best_sellers"}

#: The 26 shoppable Amazon departments. Derived from PRODUCT_CATEGORIES so
#: the backend and mobile chips can never drift apart.
DEPARTMENTS: list[str] = [c for c in PRODUCT_CATEGORIES if c not in UI_FILTER_SLUGS]

#: Search queries per department for the Amazon discovery adapter.
#: Rotated per run (index = run counter % len) so departments don't get the
#: same query every hour. These are plain search terms, not product data.
DEPARTMENT_QUERIES: dict[str, list[str]] = {
    "tech": ["wireless earbuds", "bluetooth speaker", "smart watch"],
    "fashion": ["mens sneakers", "summer dress", "sunglasses"],
    "home": ["air fryer", "robot vacuum", "bedding set"],
    "fitness": ["dumbbells set", "yoga mat", "resistance bands"],
    "beauty": ["vitamin c serum", "hair dryer", "moisturizer"],
    "computers": ["laptop", "mechanical keyboard", "4k monitor"],
    "smart_home": ["video doorbell", "smart plug", "robot vacuum"],
    "arts_crafts": ["paint set", "crochet kit", "sketchbook"],
    "automotive": ["car vacuum", "dash cam", "car mount phone"],
    "baby": ["baby monitor", "stroller", "diaper bag"],
    "health": ["vitamins", "electric toothbrush", "first aid kit"],
    "industrial": ["safety goggles", "workbench", "tool organizer"],
    "luggage": ["suitcase set", "travel backpack", "packing cubes"],
    "movies_tv": ["4k blu ray player", "tv wall mount", "streaming stick"],
    "pet_supplies": ["dog bed", "cat tree", "pet camera"],
    "software": ["antivirus software", "photo editing software"],
    "sports": ["camping tent", "hiking backpack", "pickleball set"],
    "tools": ["cordless drill", "tool set", "tape measure"],
    "toys": ["lego set", "board game", "rc car"],
    "video_games": ["ps5 controller", "nintendo switch game", "gaming headset"],
    "grocery": ["coffee beans", "honey", "protein bars"],
    "handmade": ["handmade candle", "artisan soap", "handwoven basket"],
    "books": ["bestseller novel", "cookbook", "self help book"],
    "office": ["standing desk", "office chair", "notebook set"],
    "phones": ["phone case", "magsafe charger", "screen protector"],
    "collectibles": ["funko pop", "trading cards", "action figure"],
}

BROWSER_UA = (
    "Mozilla/5.0 (Linux; Android 14; CPH2557) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
)


def _default_gallery_dir() -> Path:
    # backend/app/curation/config.py -> backend/app/static/gallery
    return Path(__file__).resolve().parent.parent / "static" / "gallery"


def gallery_dir() -> Path:
    """Writable gallery dir. Railway: VIRELLO_GALLERY_DIR=/data/gallery
    (persistent volume). Local: backend/app/static/gallery."""
    override = os.environ.get("VIRELLO_GALLERY_DIR", "").strip()
    d = Path(override) if override else _default_gallery_dir()
    try:
        d.mkdir(parents=True, exist_ok=True)
    except OSError:
        # Read-only fs (Vercel): writes go to /tmp instead.
        d = Path("/tmp") / "virello-gallery"
        _ensure_dir(d)
    return d


def static_gallery_dir() -> Path:
    """Git-committed fallback gallery (backend/app/static/gallery).
    Read-only fallback: never create it — callers only check is_file()."""
    return _ensure_dir(_default_gallery_dir())


def public_base_url() -> str:
    return os.environ.get(
        "VIRELLO_PUBLIC_BASE_URL",
        "https://virello-api-production.up.railway.app",
    ).rstrip("/")


def curation_enabled() -> bool:
    return os.environ.get("VIRELLO_CURATION_AUTONOMOUS", "true").strip().lower() in (
        "1", "true", "yes", "on",
    )


def curation_interval_hours() -> float:
    # Default 3h (Hafiz, 2026-10-01): curation pace reduced from hourly to
    # every 3 hours to slow GitHub gallery growth. Overridable via
    # VIRELLO_CURATION_INTERVAL_HOURS env var.
    try:
        return max(0.25, float(os.environ.get("VIRELLO_CURATION_INTERVAL_HOURS", "3")))
    except ValueError:
        return 3.0


def new_per_dept() -> int:
    """Growth quota: NEW products to add per department per cycle, on top of
    the >=1-per-department floor. Default 1 → up to 26 new products per
    cycle when discovery yields; the catalog keeps growing with no external
    operator (Hafiz, 2026-10-21: curation must run from the backend alone).
    0 = floor-keeping only. Overridable via VIRELLO_CURATION_NEW_PER_DEPT."""
    try:
        return max(0, int(os.environ.get("VIRELLO_CURATION_NEW_PER_DEPT", "1")))
    except ValueError:
        return 1


def curator_creator_email() -> str:
    """Creator account products are attributed to. Env first, then the
    affiliate.yaml the curator pipeline already uses. Empty → runs skip
    listing (logged) rather than attributing to nobody."""
    email = os.environ.get("VIRELLO_CURATOR_CREATOR_EMAIL", "").strip().lower()
    if email:
        return email
    # Fallback: the primary admin account. The admin allowlist is always
    # configured in production (the Admin Panel depends on it), so the
    # autonomous cycle can attribute listings without any extra env var.
    try:
        from app.core.config import settings
        admins = [e.strip().lower() for e in
                  (settings.admin_emails or "").split(",") if e.strip()]
        if admins:
            return admins[0]
    except Exception:
        pass
    for path in (
        Path.home() / "workspace" / "virello" / "affiliate.yaml",
        Path("/home/hatch/workspace/virello/affiliate.yaml"),
    ):
        try:
            if path.exists():
                import re
                m = re.search(
                    r"curator_creator_email:\s*['\"]?([^'\"\s#]+)",
                    path.read_text(encoding="utf-8"),
                )
                if m:
                    return m.group(1).strip().lower()
        except OSError:
            continue
    return ""


def partner_tag() -> str:
    return os.environ.get("VIRELLO_AMAZON_PARTNER_TAG", "topitems0c1-20").strip()


def log_path() -> Path:
    override = os.environ.get("VIRELLO_CURATION_LOG_PATH", "").strip()
    if override:
        p = Path(override)
    else:
        p = _default_gallery_dir().parent / "curation_runs.log"
    _ensure_dir(p.parent)
    return p


def mask_email(email: str) -> str:
    """For logs: alif01fiverr@gmail.com → a***@gmail.com. Never log raw."""
    if "@" not in email:
        return "***"
    local, domain = email.split("@", 1)
    return f"{local[:1]}***@{domain}"
