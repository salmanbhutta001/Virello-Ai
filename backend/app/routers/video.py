"""AI Video Generation proxy — Create Hub "Video" tab online mode.

POST /video/generate  {prompt, duration_sec?} -> {job_id, status}
GET  /video/jobs/{job_id}                            -> {status, video_url?, error?}
GET  /video/status                                   -> {available: bool}

The provider key lives server-side (VIRELLO_AGNES_API_KEY) — it is never
shipped in the APK. Currently backed by Agnes AI's free tier
(agnes-video-v2.0, https://apihub.agnes-ai.com/v1).

Jobs are DB-backed (video_jobs) so polling works across uvicorn workers —
an in-memory store returned 404 "Unknown video job" whenever a poll
landed on a different worker.
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.models.video import VideoJob

logger = logging.getLogger(__name__)
router = APIRouter()

_AGNES_BASE = "https://apihub.agnes-ai.com/v1"
_AGNES_MODEL = "agnes-video-v2.0"  # 2026-10-16: was agnes-video-2.5-flash (rejected)
_SUBMIT_TIMEOUT = 60.0
_POLL_TIMEOUT = 30.0
_MAX_DURATION = 10  # Agnes free tier caps short clips


class GenerateRequest(BaseModel):
    prompt: str = Field(min_length=3, max_length=2000)
    duration_sec: int = Field(default=6, ge=3, le=_MAX_DURATION)
    # Hafiz 2026-10-03: default 9:16 vertical for short-form video.
    aspect: str = Field(default="9:16", max_length=10)


def _key_or_503() -> str:
    key = (settings.agnes_api_key or "").strip()
    if not key:
        raise HTTPException(
            status_code=503,
            detail="Online video generation is not configured on the server yet.",
        )
    return key


async def _prune(db: AsyncSession) -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=1)
    await db.execute(
        delete(VideoJob).where(VideoJob.created_at < cutoff))


def _job_out(job: VideoJob) -> dict:
    return {
        "job_id": job.job_id,
        "status": job.status,
        "video_url": job.video_url,
        "error": job.error,
    }


@router.get("/status")
async def video_status(_user: User = Depends(get_current_user)) -> dict:
    """Whether online video generation is available right now."""
    return {
        "available": bool((settings.agnes_api_key or "").strip()),
        "provider": "agnes" if (settings.agnes_api_key or "").strip() else None,
        "max_duration_sec": _MAX_DURATION,
    }


_DIRECTOR_SYSTEM = (
    "You are the video director for Virello AI's Create Video tool. "
    "Rewrite the user's idea into ONE vivid text-to-video prompt: subject "
    "and action, camera movement, lighting, mood, setting. At most 400 "
    "characters. Reply with ONLY the prompt text — no quotes, no notes. "
    "Never add claims about guaranteed growth, followers or income."
)


async def _direct_video_prompt(prompt: str) -> str | None:
    """Stage 1 — Muse AI directs the video prompt (Hafiz 2026-10-21:
    pehle Muse AI, phir engine). Returns the enhanced prompt, or None
    when no real AI provider answered — the caller then submits the
    user's original prompt unchanged; video never blocks on AI."""
    try:
        from app.services.ai.base import AIRequest, get_claude_first_provider
        provider = get_claude_first_provider()
        resp = await asyncio.wait_for(
            provider.complete(AIRequest(
                agent="video_director",
                system=_DIRECTOR_SYSTEM,
                user=prompt,
                max_tokens=220, temperature=0.7, json_mode=False)),
            timeout=20)
    except Exception as exc:
        logger.info("video direction unavailable: %s", exc)
        return None
    if resp.dev:
        logger.info("video direction skipped: dev/fallback provider")
        return None
    text = " ".join((resp.text or "").strip().strip('"').split())
    if len(text) < 10:
        return None
    logger.info("video prompt directed by %s (%d -> %d chars)",
                resp.provider, len(prompt), len(text))
    return text[:500]


@router.post("/generate")
async def generate_video(
    body: GenerateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Submit a text-to-video job. Poll GET /video/jobs/{job_id} for result."""
    key = _key_or_503()
    await _prune(db)
    # Muse AI direction first, Agnes renders second.
    final_prompt = await _direct_video_prompt(body.prompt) or body.prompt
    try:
        async with httpx.AsyncClient(timeout=_SUBMIT_TIMEOUT) as client:
            resp = await client.post(
                f"{_AGNES_BASE}/videos",
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": _AGNES_MODEL,
                    "prompt": final_prompt,
                    # Hafiz 2026-10-13: 2.5-flash rejects 'duration' param.
                    # Hafiz 2026-10-03: request 9:16 vertical by default.
                    "aspect_ratio": body.aspect,
                },
            )
    except httpx.RequestError as exc:
        logger.warning("agnes submit transport error: %s", exc)
        raise HTTPException(status_code=502, detail="Video provider unreachable.") from exc

    if resp.status_code == 429:
        raise HTTPException(
            status_code=429,
            detail="Free video quota is busy right now — try again in a minute.",
        )
    if resp.status_code < 200 or resp.status_code >= 300:
        logger.warning("agnes submit HTTP %s: %s", resp.status_code, resp.text[:200])
        # Hafiz 2026-10-17: the app hardcodes its own message for HTTP 503
        # ("Online video is not configured on the server yet.") and ignores
        # the backend's detail. So instead of raising 503, create an
        # immediately-failed job carrying Hafiz's message in the error field.
        # The app polls the job and displays: "Video generation failed:
        # Your internet connection is weak. Please try again."
        # Backend-only fix — no app update needed.
        job = VideoJob(
            job_id=uuid.uuid4().hex[:12],
            user_id=user.id,
            agnes_id=None,
            status="failed",
            video_url=None,
        )
        job.error = "Your internet connection is weak. Please try again."
        try:
            db.add(job)
            await db.commit()
        except Exception:
            await db.rollback()
        return {"job_id": job.job_id, "status": job.status}

    data: dict = {}
    try:
        parsed = resp.json()
        data = parsed if isinstance(parsed, dict) else {}
    except ValueError:
        logger.warning("agnes submit returned non-JSON HTTP %s", resp.status_code)
        raise HTTPException(
            status_code=502, detail="Video provider returned an invalid response."
        ) from None
    agnes_id = data.get("video_id") or data.get("id")
    direct = data.get("video_url") or data.get("url")
    job = VideoJob(
        job_id=uuid.uuid4().hex[:12],
        user_id=user.id,
        agnes_id=agnes_id,
        status="ready" if direct else "submitted",
        video_url=direct,
    )
    if not agnes_id and not direct:
        job.status = "failed"
        job.error = "Provider returned no video ID."
    try:
        db.add(job)
        await db.commit()
    except Exception as exc:
        await db.rollback()
        logger.exception("video_jobs insert failed")
        raise HTTPException(
            status_code=502,
            detail="Could not save the video job. Please try again.",
        ) from None
    return {"job_id": job.job_id, "status": job.status}


@router.get("/jobs/{job_id}")
async def job_status(
    job_id: str,
    _user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Poll a video job. status: submitted|processing|ready|failed."""
    job = (await db.execute(
        select(VideoJob).where(VideoJob.job_id == job_id)
    )).scalar_one_or_none()
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown video job.")
    if job.status in ("ready", "failed"):
        return _job_out(job)

    key = _key_or_503()
    if not job.agnes_id:
        job.status = "failed"
        job.error = "Provider returned no video ID."
        await db.commit()
        return _job_out(job)

    try:
        async with httpx.AsyncClient(timeout=_POLL_TIMEOUT) as client:
            resp = await client.get(
                f"{_AGNES_BASE}/agnesapi",
                params={"video_id": job.agnes_id},
                headers={"Authorization": f"Bearer {key}"},
            )
    except httpx.RequestError:
        return {"job_id": job.job_id, "status": "processing", "video_url": None}

    if resp.status_code != 200:
        return {"job_id": job.job_id, "status": "processing", "video_url": None}

    try:
        data = resp.json()
    except ValueError:
        return {"job_id": job.job_id, "status": "processing", "video_url": None}

    state = str(data.get("status", "")).lower()
    if state in ("completed", "succeeded", "done", "ready"):
        job.status = "ready"
        job.video_url = data.get("video_url") or data.get("url") or data.get("video")
    elif state in ("failed", "error"):
        job.status = "failed"
        job.error = str(data.get("error") or "Video generation failed.")
    else:
        # Some responses embed the URL without a status field.
        direct = data.get("video_url") or data.get("url")
        if direct:
            job.status = "ready"
            job.video_url = direct
        else:
            job.status = "processing"
    await db.commit()
    return _job_out(job)
