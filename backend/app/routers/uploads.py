"""User content uploads — phone file -> server -> AI actions.

POST /uploads            multipart file  -> {id, filename, mime, size, kind, url}
GET  /uploads/{id}       serves the stored file (owner only)
POST /uploads/analyze    {upload_id, caption} -> honest heuristic media-readiness
                         report (metadata + caption checks, labeled estimate —
                         never presented as AI vision).

Storage: backend/uploads/{uuid}_{safe_name}. No DB table — metadata is
re-derived from the stored file, so no migration is needed.
"""
from __future__ import annotations

import io
import re
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.core.deps import get_current_user
from app.models.core import User

router = APIRouter()

UPLOAD_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

MAX_BYTES = 50 * 1024 * 1024  # 50 MB

_ALLOWED = {
    # kind: set of extensions
    "image": {"jpg", "jpeg", "png", "webp", "gif"},
    "video": {"mp4", "mov", "webm", "3gp", "mkv"},
    "document": {"pdf", "doc", "docx", "txt", "csv", "xls", "xlsx", "ppt", "pptx"},
    "audio": {"mp3", "wav", "m4a", "ogg"},
}

_SAFE_CHARS = re.compile(r"[^A-Za-z0-9._-]+")


def _safe_name(name: str) -> str:
    name = _SAFE_CHARS.sub("_", (name or "file").strip())[:80] or "file"
    return name


def _kind_of(filename: str) -> str | None:
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    for kind, exts in _ALLOWED.items():
        if ext in exts:
            return kind
    return None


def _public_id(stored: str) -> str:
    return stored.split("_", 1)[0]


@router.post("")
async def upload_file(
    file: UploadFile = File(...),
    _user: User = Depends(get_current_user),
) -> dict:
    name = _safe_name(file.filename or "file")
    kind = _kind_of(name)
    if kind is None:
        raise HTTPException(
            400,
            "Unsupported file type. Allowed: images, video, audio, documents.",
        )
    data = await file.read()
    if not data:
        raise HTTPException(400, "Empty file")
    if len(data) > MAX_BYTES:
        raise HTTPException(400, "File too large (max 50 MB)")

    uid = uuid.uuid4().hex
    stored = f"{uid}_{name}"
    (UPLOAD_DIR / stored).write_bytes(data)

    return {
        "id": uid,
        "filename": name,
        "mime": file.content_type or "application/octet-stream",
        "size": len(data),
        "kind": kind,
        "url": f"/api/v1/uploads/{uid}",
    }


def _resolve(upload_id: str) -> Path:
    if not re.fullmatch(r"[0-9a-f]{32}", upload_id or ""):
        raise HTTPException(404, "Upload not found")
    matches = list(UPLOAD_DIR.glob(f"{upload_id}_*"))
    if not matches:
        raise HTTPException(404, "Upload not found")
    return matches[0]


@router.get("/{upload_id}")
async def get_file(
    upload_id: str, _user: User = Depends(get_current_user)
) -> FileResponse:
    path = _resolve(upload_id)
    return FileResponse(path, filename=path.name.split("_", 1)[1])


class AnalyzeUploadIn(BaseModel):
    upload_id: str
    caption: str = ""


@router.post("/analyze")
async def analyze_upload(
    body: AnalyzeUploadIn, _user: User = Depends(get_current_user)
) -> dict:
    """Heuristic media-readiness report. Transparent and explainable:
    every check lists its reason. Score is an estimate, not a guarantee."""
    path = _resolve(body.upload_id)
    original = path.name.split("_", 1)[1]
    kind = _kind_of(original) or "other"
    size = path.stat().st_size
    caption = (body.caption or "").strip()

    width = height = None
    if kind == "image":
        try:
            from PIL import Image

            with Image.open(path) as im:
                width, height = im.size
        except Exception:
            width = height = None

    checks: list[dict] = []
    score = 50.0

    # 1. Caption present
    if caption:
        checks.append({"ok": True, "label": "Caption added",
                       "detail": f"{len(caption)} characters — captions lift engagement."})
        score += 10
    else:
        checks.append({"ok": False, "label": "No caption",
                       "detail": "Add a caption so the AI can match this to the right audience."})

    # 2. Hashtags
    tags = re.findall(r"#\w+", caption)
    if 1 <= len(tags) <= 8:
        checks.append({"ok": True, "label": f"{len(tags)} hashtag(s)",
                       "detail": "Good range — discoverable without looking spammy."})
        score += 8
    elif len(tags) > 8:
        checks.append({"ok": False, "label": f"{len(tags)} hashtags",
                       "detail": "More than 8 looks spammy — keep the best 3–5."})
        score -= 5
    else:
        checks.append({"ok": None, "label": "No hashtags",
                       "detail": "2–4 relevant hashtags help discovery."})

    # 3. Caption length
    if caption and len(caption) < 20:
        checks.append({"ok": None, "label": "Short caption",
                       "detail": "One more line about who this is for helps the AI."})
    elif len(caption) > 2200:
        checks.append({"ok": False, "label": "Caption too long",
                       "detail": "Platforms truncate after ~2,200 characters."})
        score -= 4

    # 4. Media quality signals (honest, metadata-only)
    if kind == "image" and width and height:
        mp = width * height / 1e6
        if mp >= 2:
            checks.append({"ok": True, "label": f"High resolution ({width}×{height})",
                           "detail": "Sharp on all screens."})
            score += 8
        elif mp >= 0.5:
            checks.append({"ok": None, "label": f"Medium resolution ({width}×{height})",
                           "detail": "Fine for feeds; avoid heavy cropping."})
            score += 3
        else:
            checks.append({"ok": False, "label": f"Low resolution ({width}×{height})",
                           "detail": "May look blurry — use a larger original if you have it."})
            score -= 8
    elif kind == "video":
        if size > 200 * 1024 * 1024:
            pass  # unreachable: 50MB cap
        checks.append({"ok": True, "label": "Video ready",
                       "detail": f"{size / 1e6:.1f} MB — vertical video under 60s performs best."})
        score += 5
    elif kind == "audio":
        checks.append({"ok": None, "label": "Audio file",
                       "detail": "Pair it with a cover image or waveform video before posting."})

    # 5. File size sanity
    if size > 40 * 1024 * 1024:
        checks.append({"ok": None, "label": "Large file",
                       "detail": "Uploads fine, but compress before posting to social apps."})
        score -= 3

    score = max(0, min(100, round(score)))
    if score >= 75:
        verdict = "Ready to grow — this looks post-worthy."
    elif score >= 50:
        verdict = "Good start — fix the notes above, then grow it."
    else:
        verdict = "Needs work before promoting — see the checklist."

    recommendations = [
        c["detail"] for c in checks if c["ok"] is not True
    ][:4]

    return {
        "upload_id": body.upload_id,
        "filename": original,
        "kind": kind,
        "size": size,
        "width": width,
        "height": height,
        "caption_length": len(caption),
        "hashtags": tags[:8],
        "score": score,
        "score_label": "heuristic estimate — not a guarantee of reach",
        "verdict": verdict,
        "checks": checks,
        "recommendations": recommendations,
        "method": "heuristic",
    }
