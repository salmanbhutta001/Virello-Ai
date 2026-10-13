"""AI Content Creation API — Phase 3 of the Virello evolution (text-first).

POST /create/ideas    {topic, count?, language?} -> content ideas
POST /create/scripts  {topic, format?, language?} -> script (hook/body/cta)
POST /create/captions {topic, platform?, language?} -> captions + hashtags
POST /create/hooks    {topic, count?, language?} -> opening hooks

All generation goes through the AI provider ABC. The dev provider returns
deterministic heuristic templates, always labeled. No media (image/video/
voice) generation yet — text only, honestly.
"""
from __future__ import annotations

import asyncio
import json
import logging
import random
import uuid
from datetime import datetime, timedelta, timezone

import httpx

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import SessionLocal, get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.models.image import ImageJob
from app.services.ai.base import AIRequest, get_ai_provider

logger = logging.getLogger(__name__)
router = APIRouter()

DEV_NOTE = (
    "Development preview — heuristic output. "
    "Connect a production AI provider for richer generation."
)

_DISCLAIMER = (
    "Original starting points to edit and make your own — "
    "not a prediction or guarantee of reach, virality, or sales."
)

_LANG_NAMES = {"en": "English", "ur": "Urdu", "ar": "Arabic"}


def _lang(code: str | None) -> str:
    code = (code or "en").lower()
    return code if code in _LANG_NAMES else "en"


# ---------------------------------------------------------------------------
# Heuristic (dev) generators — deterministic templates, always labeled
# ---------------------------------------------------------------------------

_IDEA_FORMATS = ["short video", "carousel", "talking-head reel", "text post", "tutorial clip"]


def _heuristic_ideas(topic: str, count: int) -> list[dict]:
    topic = topic.strip() or "your niche"
    angles = [
        ("myth-busting", f"3 myths about {topic} (busted)"),
        ("beginner guide", f"{topic} for absolute beginners"),
        ("mistakes", f"5 mistakes everyone makes with {topic}"),
        ("behind the scenes", f"A day working on {topic}"),
        ("transformation", f"{topic}: before vs after"),
        ("quick tips", f"{topic} in 60 seconds"),
        ("story", f"How I got into {topic}"),
        ("comparison", f"{topic} vs the alternative — honest take"),
    ]
    out = []
    for i, (angle, title) in enumerate(angles[: max(1, min(count, len(angles)))]):
        out.append({
            "title": title,
            "format": _IDEA_FORMATS[i % len(_IDEA_FORMATS)],
            "angle": angle,
            "brief": f"Hook viewers with the {angle} angle, deliver one clear takeaway about {topic}, end with a question.",
        })
    return out


def _heuristic_script(topic: str, format: str) -> dict:
    topic = topic.strip() or "your niche"
    format = (format or "video").lower()
    if format not in ("video", "reel", "post"):
        format = "video"
    beats = 5 if format in ("video", "reel") else 3
    return {
        "topic": topic,
        "format": format,
        "hook": f"Stop scrolling — here's the one thing about {topic} nobody tells you…",
        "body": [
            f"Beat {i + 1}: one clear point about {topic} (keep it under 10 seconds)."
            for i in range(beats)
        ],
        "cta": "Follow for part 2 — and tell me your experience in the comments.",
    }


def _heuristic_captions(topic: str, platform: str | None) -> list[dict]:
    topic = topic.strip() or "your niche"
    tag_base = "".join(c for c in topic.lower() if c.isalnum())
    tags = [f"#{tag_base}", "#contentcreator", "#tips", "#learnontiktok", "#viral"]
    return [
        {
            "caption": f"Everything I wish I knew about {topic} 👇\n\nSave this for later — part 2 drops tomorrow.",
            "hashtags": tags[:5],
            "tone": "helpful",
        },
        {
            "caption": f"POV: you finally understand {topic} 😅\n\nTag someone who needs this.",
            "hashtags": tags[:4],
            "tone": "playful",
        },
        {
            "caption": f"{topic.capitalize()} — explained in 30 seconds.\n\nFollow for daily breakdowns.",
            "hashtags": tags[:3],
            "tone": "direct",
        },
    ]


def _heuristic_hooks(topic: str, count: int) -> list[str]:
    topic = (topic.strip() or "this").rstrip(".")
    templates = [
        f"Stop doing {topic} wrong — do this instead…",
        f"The {topic} trick nobody talks about 👀",
        f"I tried {topic} for 30 days. Here's what happened…",
        f"3 {topic} mistakes that are costing you…",
        f"POV: you finally master {topic}",
        f"Why 99% of people fail at {topic}…",
        f"{topic} explained so simply a 5-year-old gets it…",
    ]
    return templates[: max(1, min(count, len(templates)))]


# ---------------------------------------------------------------------------
# Live-provider path (JSON mode, strict parse, heuristic fallback)
# ---------------------------------------------------------------------------

async def _ai_json(agent: str, system: str, user: str,
                   max_tokens: int = 900) -> tuple[dict | None, str, bool]:
    """Return (parsed_json_or_None, provider_name, dev)."""
    prov = get_ai_provider()
    if prov.name == "dev":
        return None, prov.name, True
    try:
        resp = await prov.complete(AIRequest(
            agent=agent, system=system, user=user,
            max_tokens=max_tokens, temperature=0.8, json_mode=True))
        data = json.loads(resp.text)
        return (data if isinstance(data, dict) else None,
                resp.provider, bool(resp.dev))
    except Exception as exc:  # fail closed -> heuristics
        logger.warning("create provider failed: %s", exc)
        return None, prov.name, True


def _envelope(payload: dict, provider: str, dev: bool) -> dict:
    payload["provider"] = provider
    payload["dev"] = dev
    payload["dev_note"] = DEV_NOTE if dev else None
    payload["disclaimer"] = _DISCLAIMER
    return payload


# ---------------------------------------------------------------------------
# Create & Earn: Grow credits pay for generations. Costs come from settings
# (admin-tunable); the user's level discount applies server-side.
# 402 = not enough credits -> the app deep-links to Rewards to earn more.
# ---------------------------------------------------------------------------
REWARDS_DEEP_LINK = "virello://wallet"


async def _generation_gate(db: AsyncSession, user: User,
                           kind: str) -> dict:
    """Pre-generation affordability check. 402 when the balance is low."""
    from app.services import rewards as rewards_svc
    info = await rewards_svc.generation_cost(db, user.id, kind)
    if info["credits_balance"] < info["charged_credits"]:
        raise HTTPException(402, {
            "error": "insufficient_credits",
            "needed_credits": info["charged_credits"],
            "credits_balance": info["credits_balance"],
            "level": info["level"],
            "message": ("Not enough Grow credits for this. "
                        "Earn more in Rewards — post, share, and convert "
                        "points to credits."),
            "rewards_deep_link": REWARDS_DEEP_LINK,
        })
    return info


async def _settle_generation(db: AsyncSession, user: User, kind: str,
                             payload: dict, provider: str,
                             dev: bool) -> dict:
    """Charge AFTER successful generation; attach the credit receipt."""
    from app.services import rewards as rewards_svc
    try:
        info = await rewards_svc.charge_generation(db, user.id, kind)
    except rewards_svc.GenerationError:
        # Raced to empty between gate and charge: the content is already
        # generated, so return it rather than failing the request.
        logger.warning("create: post-generation charge failed user=%s kind=%s",
                       user.id, kind)
        payload["credits"] = {"charged_credits": 0,
                              "credits_balance": 0}
        return _envelope(payload, provider, dev)
    payload["credits"] = {
        "charged_credits": info["charged_credits"],
        "discount_pct": info["discount_pct"],
        "level": info["level"],
        "credits_balance": info["credits_balance"],
    }
    return _envelope(payload, provider, dev)


@router.get("/costs")
async def costs(db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    """What each generation costs THIS user (level discount applied) —
    the Create screens show this before generating."""
    from app.services import rewards as rewards_svc
    raw = await rewards_svc.get_create_costs(db)
    out = {}
    level = None
    balance = 0
    for kind in raw:
        info = await rewards_svc.generation_cost(db, user.id, kind)
        out[kind] = {"base_credits": info["base_credits"],
                     "charged_credits": info["charged_credits"],
                     "discount_pct": info["discount_pct"]}
        level, balance = info["level"], info["credits_balance"]
    return {"costs": out, "level": level,
            "level_discounts": rewards_svc.LEVEL_DISCOUNTS,
            "credits_balance": balance,
            "rewards_deep_link": REWARDS_DEEP_LINK}


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

class IdeasIn(BaseModel):
    topic: str
    count: int = Field(default=5, ge=1, le=8)
    language: str | None = None


@router.post("/ideas")
async def ideas(body: IdeasIn, db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    await _generation_gate(db, user, "ideas")
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant. Generate original short content "
        f"ideas in {_LANG_NAMES[lang]}. Return ONLY JSON: "
        '{"ideas": [{"title": "...", "format": "...", "angle": "...", "brief": "..."}]}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nCount: {body.count}")
    items = None
    if data:
        raw = data.get("ideas") or []
        items = [i for i in raw if isinstance(i, dict) and i.get("title")][: body.count]
    if not items:
        items = _heuristic_ideas(body.topic, body.count)
        dev = True
    return await _settle_generation(
        db, user, "ideas", {"ideas": items, "count": len(items)},
        provider, dev)


class ScriptIn(BaseModel):
    topic: str
    format: str = "video"  # video | reel | post
    language: str | None = None


@router.post("/scripts")
async def scripts(body: ScriptIn, db: AsyncSession = Depends(get_db),
                  user: User = Depends(get_current_user)) -> dict:
    await _generation_gate(db, user, "script")
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant writing in {_LANG_NAMES[lang]}. "
        "Return ONLY JSON: "
        '{"hook": "...", "body": ["beat 1", "beat 2", ...], "cta": "..."}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nFormat: {body.format}")
    script = None
    if data and data.get("hook") and isinstance(data.get("body"), list):
        script = {"topic": body.topic, "format": body.format,
                  "hook": str(data["hook"])[:300],
                  "body": [str(b)[:300] for b in data["body"][:8]],
                  "cta": str(data.get("cta", ""))[:300]}
    if not script:
        script = _heuristic_script(body.topic, body.format)
        dev = True
    return await _settle_generation(
        db, user, "script", {"script": script}, provider, dev)


class CaptionsIn(BaseModel):
    topic: str
    platform: str | None = None
    language: str | None = None


@router.post("/captions")
async def captions(body: CaptionsIn, db: AsyncSession = Depends(get_db),
                   user: User = Depends(get_current_user)) -> dict:
    await _generation_gate(db, user, "captions")
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant writing in {_LANG_NAMES[lang]}. "
        "Return ONLY JSON: "
        '{"captions": [{"caption": "...", "hashtags": ["#a"], "tone": "..."}]}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nPlatform: {body.platform or 'any'}")
    items = None
    if data:
        raw = data.get("captions") or []
        items = [c for c in raw if isinstance(c, dict) and c.get("caption")][:5]
    if not items:
        items = _heuristic_captions(body.topic, body.platform)
        dev = True
    return await _settle_generation(
        db, user, "captions", {"captions": items, "count": len(items)},
        provider, dev)


class HooksIn(BaseModel):
    topic: str
    count: int = Field(default=5, ge=1, le=7)
    language: str | None = None


@router.post("/hooks")
async def hooks(body: HooksIn, db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    await _generation_gate(db, user, "hooks")
    lang = _lang(body.language)
    data, provider, dev = await _ai_json(
        "creator",
        f"You are Virello's Creator assistant writing in {_LANG_NAMES[lang]}. "
        'Return ONLY JSON: {"hooks": ["...", "..."]}. '
        "Never promise virality, reach or sales.",
        f"Topic: {body.topic}\nCount: {body.count}")
    items = None
    if data and isinstance(data.get("hooks"), list):
        items = [str(h)[:200] for h in data["hooks"] if h][: body.count]
    if not items:
        items = _heuristic_hooks(body.topic, body.count)
        dev = True
    return await _settle_generation(
        db, user, "hooks", {"hooks": items, "count": len(items)},
        provider, dev)


# ---------------------------------------------------------------------------
# AI image generation via Agnes (Hafiz 2026-10-03)
# Pollinations is unreachable from some phones/networks (DNS fails), so
# Create Image now uses Agnes AI's image model through the backend proxy
# (key stays server-side, same pattern as /api/v1/video).
# ---------------------------------------------------------------------------

_AGNES_IMAGE_BASE = "https://apihub.agnes-ai.com/v1"
_AGNES_IMAGE_MODEL = "agnes-image-2.5-flash"


class AgnesImageIn(BaseModel):
    prompt: str = Field(min_length=3, max_length=1000)
    style: str = Field(default="realistic", max_length=20)
    seed: int = Field(default=0, ge=0)


_AGNES_STYLE_SUFFIX = {
    "realistic": "photorealistic, highly detailed, professional photography",
    "cartoon": "cartoon style, vibrant illustration, animated",
    "3d": "3d render, octane render, detailed 3d illustration",
}


def _agnes_image_key() -> str:
    from app.core.config import settings
    key = (settings.agnes_api_key or "").strip()
    if not key:
        raise HTTPException(
            status_code=503,
            detail="AI image generation is not configured on the server yet.",
        )
    return key


# ---------------------------------------------------------------------------
# Async image jobs — POST /image-agnes returns 202 + {job_id} immediately;
# a background task performs the Agnes call; the app polls
# GET /image-jobs/{job_id} until status is ready|failed.
# (Hafiz 2026-10-13: the old synchronous 120s call timed out too often —
#  this is the permanent fix, mirroring the /video job pattern.)
# ---------------------------------------------------------------------------

_IMAGE_JOB_TTL = timedelta(hours=1)      # prune jobs older than this
_IMAGE_JOB_TIMEOUT = 300.0               # background-task safety timeout (s)
_IMAGE_JOB_STALE_AFTER = timedelta(minutes=10)  # orphan reaper threshold


async def _prune_image_jobs(db: AsyncSession) -> None:
    """Delete image jobs older than _IMAGE_JOB_TTL. Lazy cleanup, like video."""
    cutoff = datetime.now(timezone.utc) - _IMAGE_JOB_TTL
    await db.execute(delete(ImageJob).where(ImageJob.created_at < cutoff))


async def _agnes_image_generate_inline(
    prompt: str, style: str, seed: int | None, request_id: str,
) -> str:
    """Legacy synchronous Agnes image call (pre-async rollout).

    Raises HTTPException (503/502/429) on failure — the same contract as
    the old POST /image-agnes. Used for ?sync=true and as a fallback when
    app.services.agnes_client is not (yet) available.
    """
    key = _agnes_image_key()
    suffix = _AGNES_STYLE_SUFFIX.get(style, _AGNES_STYLE_SUFFIX["realistic"])
    full_prompt = f"{prompt}, {suffix}"
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                f"{_AGNES_IMAGE_BASE}/images/generations",
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": _AGNES_IMAGE_MODEL,
                    "prompt": full_prompt,
                    "n": 1,
                    "size": "1024x1024",
                    # Pass the seed through when the app sends one (Regenerate).
                    **({"seed": seed} if seed is not None else {}),
                },
            )
    except httpx.RequestError as exc:
        logger.warning("agnes image transport error [%s]: %s", request_id, exc)
        raise HTTPException(
            status_code=502, detail="Image service unreachable.") from exc
    if resp.status_code == 429:
        raise HTTPException(
            status_code=429,
            detail="Image quota is busy right now — try again in a minute.")
    if resp.status_code < 200 or resp.status_code >= 300:
        logger.warning(
            "agnes image HTTP %s [%s]: %s", resp.status_code, request_id,
            resp.text[:200])
        raise HTTPException(
            status_code=502, detail="Image service rejected the request.")
    try:
        data = resp.json()
        url = data["data"][0]["url"]
    except (KeyError, IndexError, TypeError, ValueError):
        raise HTTPException(
            status_code=502, detail="Image service returned invalid data.")
    if not url:
        raise HTTPException(
            status_code=502, detail="Image service returned no image.")
    return url


async def _process_image_job(job_id: str, request_id: str) -> None:
    """Background worker for one image job. Own DB session — never touches
    the request's session. Never raises: all failures land on the job row."""
    try:
        async with SessionLocal() as db:
            job = (await db.execute(
                select(ImageJob).where(ImageJob.id == job_id)
            )).scalar_one_or_none()
            if job is None:
                logger.warning(
                    "image job %s [%s]: row vanished before processing",
                    job_id, request_id)
                return
            job.status = "processing"
            await db.commit()

            try:
                try:
                    from app.services.agnes_client import agnes_image_generate
                except ImportError:
                    logger.warning(
                        "image job %s [%s]: agnes_client missing — "
                        "inline fallback", job_id, request_id)
                    url = await asyncio.wait_for(
                        _agnes_image_generate_inline(
                            job.prompt, job.style, job.seed, request_id),
                        timeout=_IMAGE_JOB_TIMEOUT,
                    )
                else:
                    suffix = _AGNES_STYLE_SUFFIX.get(
                        job.style, _AGNES_STYLE_SUFFIX["realistic"])
                    url = await asyncio.wait_for(
                        agnes_image_generate(
                            prompt=job.prompt,
                            style_suffix=suffix,
                            seed=job.seed,
                            request_id=request_id,
                        ),
                        timeout=_IMAGE_JOB_TIMEOUT,
                    )
                job.status = "ready"
                job.image_url = url
                logger.info(
                    "image job %s [%s]: ready", job_id, request_id)
            except Exception as exc:
                job.status = "failed"
                detail = (exc.detail if isinstance(exc, HTTPException)
                          else str(exc)) or "Image generation failed."
                job.error = detail[:500]
                logger.warning(
                    "image job %s [%s]: failed: %s", job_id, request_id,
                    detail[:200])
            await db.commit()
    except Exception:
        logger.exception(
            "image job %s [%s]: background task crashed", job_id, request_id)


@router.post("/image-agnes")
async def generate_image_agnes(
    body: AgnesImageIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    sync: bool = Query(
        default=False,
        description="Legacy blocking flow — returns {image_url} directly. "
                    "Default (async) returns 202 {job_id, status}.",
    ),
) -> dict:
    """Generate an image via Agnes AI (server-side key).

    Async by default: persists an ImageJob and returns 202 immediately —
    the Agnes call runs in a background task. Poll
    GET /image-jobs/{job_id} for the result. Pass ?sync=true for the
    legacy blocking behavior during rollout.
    """
    request_id = uuid.uuid4().hex
    if sync:
        url = await _agnes_image_generate_inline(
            body.prompt, body.style, body.seed, request_id)
        return {"image_url": url}

    # Fail fast when the provider key is missing (same 503 as before),
    # before a job row is created.
    _agnes_image_key()
    await _prune_image_jobs(db)
    job = ImageJob(
        id=uuid.uuid4().hex,
        user_id=user.id,
        prompt=body.prompt,
        style=body.style,
        seed=body.seed,
        status="pending",
        request_id=request_id,
    )
    try:
        db.add(job)
        await db.commit()
    except Exception:
        await db.rollback()
        logger.exception("image_jobs insert failed [%s]", request_id)
        raise HTTPException(
            status_code=502,
            detail="Could not save the image job. Please try again.",
        ) from None
    logger.info(
        "image job %s submitted [%s] user=%s style=%s",
        job.id, request_id, user.id, body.style)
    asyncio.create_task(_process_image_job(job.id, request_id))
    return JSONResponse(
        status_code=202,
        content={"job_id": job.id, "status": job.status},
    )


@router.get("/image-jobs/{job_id}")
async def image_job_status(
    job_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Poll an image job. status: pending|processing|ready|failed.

    404 when the job does not exist, belongs to another user, or was
    pruned (>1h old).
    """
    await _prune_image_jobs(db)
    job = (await db.execute(
        select(ImageJob).where(
            ImageJob.id == job_id,
            ImageJob.user_id == user.id,
        )
    )).scalar_one_or_none()
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown image job.")
    if job.status in ("pending", "processing"):
        # Stale reaper: a worker crash/restart can orphan a job in a
        # non-terminal state — never leave the app polling forever.
        updated = job.updated_at
        if updated is not None and updated.tzinfo is None:
            updated = updated.replace(tzinfo=timezone.utc)
        if (updated is None
                or datetime.now(timezone.utc) - updated > _IMAGE_JOB_STALE_AFTER):
            old = job.status
            job.status = "failed"
            job.error = "Generation timed out. Please try again."
            await db.commit()
            logger.warning(
                "image job %s: reaped stale %s job", job.id, old)
    return {
        "job_id": job.id,
        "status": job.status,
        "image_url": job.image_url,
        "error": job.error,
    }
