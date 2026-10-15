"""Creator Hub media API — real generation endpoints.

- POST /api/v1/media/generate-image   — real AI image via the configured
  ImageProvider (default: Pollinations.ai, free/keyless, modular).
- POST /api/v1/media/generate-caption — real AI hook/caption/hashtags via
  the configured AIProvider (Groq/OpenAI/Anthropic/Google, else dev).

Both are PUBLIC: Creator Hub is free on all plans (no credit deduction).
A light per-IP rate limit guards the shared provider quota. Failures are
reported honestly — never a fake placeholder.
"""
from __future__ import annotations

import json
import time
from collections import defaultdict, deque

import httpx
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.services.ai.base import AIRequest, get_ai_provider
from app.services.image_provider import (
    ImageProviderError,
    ImageProviderNotConfigured,
    ImageRequest,
    get_image_provider,
)

router = APIRouter()

# --- light per-IP rate limiting (in-memory; single-instance friendly) ---
_RATE_LIMITS = {
    "generate-image": (30, 3600),    # 30 images / hour / IP
    "generate-caption": (60, 3600),  # 60 captions / hour / IP
    "generate-text": (60, 3600),     # 60 AI text generations / hour / IP
    "assemble-video": (8, 3600),     # 8 MP4 assemblies / hour / IP (CPU-heavy)
}
_hits: dict[str, deque] = defaultdict(deque)


def _check_rate_limit(request: Request, key: str) -> None:
    limit, window = _RATE_LIMITS[key]
    ip = (request.client.host if request.client else "unknown") + ":" + key
    now = time.monotonic()
    dq = _hits[ip]
    while dq and now - dq[0] > window:
        dq.popleft()
    if len(dq) >= limit:
        raise HTTPException(
            status_code=429,
            detail=f"Rate limit reached ({limit}/hour). Try again later.",
        )
    dq.append(now)


_ASPECTS = {
    "4:5": (864, 1080),
    "9:16": (810, 1440),
    "1:1": (1080, 1080),
}


class GenerateImageIn(BaseModel):
    prompt: str = Field(min_length=3, max_length=600)
    aspect: str = Field(default="4:5")


class GenerateImageOut(BaseModel):
    image_url: str
    provider: str
    model: str
    width: int
    height: int


@router.post("/generate-image", response_model=GenerateImageOut)
async def generate_image(body: GenerateImageIn, request: Request):
    """Generate a real AI image for the Creator Hub Image Studio."""
    _check_rate_limit(request, "generate-image")
    width, height = _ASPECTS.get(body.aspect, _ASPECTS["4:5"])
    try:
        provider = get_image_provider()
    except ImageProviderNotConfigured as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    try:
        # Vary the seed per call so "Regenerate" gives a fresh image.
        seed = int(time.time() * 1000) % 999983
        result = await provider.generate(
            ImageRequest(prompt=body.prompt, width=width, height=height, seed=seed)
        )
    except ImageProviderError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Image generation failed: {exc}. Please try again.",
        )
    return GenerateImageOut(
        image_url=result.image_url,
        provider=result.provider,
        model=result.model,
        width=result.width,
        height=result.height,
    )


class GenerateCaptionIn(BaseModel):
    topic: str = Field(min_length=3, max_length=500)
    niche: str = Field(default="", max_length=80)
    goal: str = Field(default="", max_length=80)


class GenerateCaptionOut(BaseModel):
    hook: str
    caption: str
    hashtags: list[str]
    provider: str
    model: str
    dev: bool = False


_CAPTION_SYSTEM = """You are Virello's Caption & Hook Writer, an expert social-media
copywriter for Instagram Reels, TikTok and YouTube Shorts. Write in the
creator's voice: punchy, authentic, no corporate fluff, no fake claims.
Never invent statistics, earnings or guarantees. Respond with a JSON object
containing exactly these keys: "hook" (one scroll-stopping opening line,
max 15 words), "caption" (2-4 short lines, emoji sparingly, ends with a
soft CTA like save/share), "hashtags" (array of 8-12 relevant hashtag
strings WITHOUT the # character, mixing niche and broad tags)."""


@router.post("/generate-caption", response_model=GenerateCaptionOut)
async def generate_caption(body: GenerateCaptionIn, request: Request):
    """Write a real AI hook + caption + hashtags for the Creator Hub."""
    _check_rate_limit(request, "generate-caption")
    user_prompt = f"Topic: {body.topic}"
    if body.niche:
        user_prompt += f"\nNiche: {body.niche}"
    if body.goal:
        user_prompt += f"\nGoal: {body.goal}"
    try:
        provider = get_ai_provider()
        resp = await provider.complete(
            AIRequest(
                agent="caption_writer",
                system=_CAPTION_SYSTEM,
                user=user_prompt,
                max_tokens=600,
                temperature=0.8,
                json_mode=True,
            )
        )
        dev_fallback = resp.dev
    except HTTPException:
        raise
    except Exception as exc:  # provider errors -> honest 502, never fake text
        raise HTTPException(
            status_code=502,
            detail=f"Caption generation failed ({type(exc).__name__}): {str(exc)[:120]}",
        )
    data = None
    if not dev_fallback:
        try:
            data = json.loads(resp.text)
        except (ValueError, TypeError):
            data = None
    provider_label = resp.provider
    # Fallback: free/keyless Pollinations text API when no production AI
    # provider is configured. Labeled honestly in the response.
    if data is None or not str(data.get("hook", "")).strip():
        data = await _pollinations_caption(user_prompt)
        provider_label = "pollinations"
    if data is None:
        raise HTTPException(
            status_code=503,
            detail="AI caption writer is not configured (no production AI provider).",
        )
    hashtags = data.get("hashtags") or []
    hashtags = [str(h).lstrip("#").strip() for h in hashtags][:12]
    return GenerateCaptionOut(
        hook=str(data.get("hook", "")).strip(),
        caption=str(data.get("caption", "")).strip(),
        hashtags=hashtags,
        provider=provider_label,
        model=resp.model,
        dev=False,
    )


async def _pollinations_caption(user_prompt: str) -> dict | None:
    """Free/keyless caption fallback via Pollinations text API.

    Used only when no production AI provider is configured. Returns a
    dict with hook/caption/hashtags, or None on failure.
    """
    import urllib.parse

    import httpx

    prompt = (
        "You are Virello's Caption Writer, an expert social-media copywriter. "
        "Write punchy, authentic copy. Never invent statistics or guarantees. "
        "Reply with ONLY a JSON object with keys: \"hook\" (one scroll-stopping "
        "line, max 15 words), \"caption\" (2-4 short lines, emoji sparingly, ends "
        "with a soft CTA), \"hashtags\" (array of 8-12 hashtag strings WITHOUT "
        "the # character).\n\n" + user_prompt
    )
    url = "https://text.pollinations.ai/" + urllib.parse.quote(prompt[:800])
    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(90.0, connect=15.0)
        ) as client:
            resp = await client.get(url)
            if resp.status_code != 200:
                return None
            text = resp.text.strip()
            # Strip markdown code fences if present.
            if text.startswith("```"):
                text = text.strip("`").strip()
                if text.lower().startswith("json"):
                    text = text[4:].strip()
            data = json.loads(text)
            if not isinstance(data, dict) or not str(data.get("hook", "")).strip():
                return None
            return data
    except Exception:
        return None


# ---------------------------------------------------------------------------
# AI text tools (Script Writer, Story Writer, Content Converter)
# ---------------------------------------------------------------------------

_TEXT_SYSTEMS = {
    "script": """You are Virello's Script Writer, an expert short-form video scriptwriter for Instagram Reels, TikTok and YouTube Shorts. Write a REAL structured script in the creator's voice: punchy, authentic, no corporate fluff, no fake claims or invented statistics. Format exactly as:
HOOK: (one scroll-stopping opening line, max 12 words)
BEATS: (3-5 timed beats like 0:00-0:03 — what happens on screen + what is said)
CTA: (one soft call to action)
Keep the whole script under 220 words. Output ONLY the final script — never show your reasoning or thinking process.""",
    "story": """You are Virello's Story Writer, a skilled storyteller for social media. Write a REAL, engaging story in the requested length and language: vivid, emotional, authentic. No fake claims or invented statistics. Plain paragraphs, no headings. Output ONLY the final story — never show your reasoning or thinking process.""",
    "convert": """You are Virello's Content Converter. Convert the user's text into the requested native format, keeping the core message and voice. Never invent statistics, earnings or guarantees. Formats:
- Video Script: HOOK line, 3-5 timed BEATS, CTA
- Carousel: 5-7 slide texts (Slide 1 is the hook), each under 25 words
- Thread: 5-8 short posts, first one is the hook, numbered
- Story Caption: 2-4 short lines with a soft CTA
Reply with ONLY the converted content. Never show your reasoning or thinking process.""",
}

_TEXT_LENGTHS = {
    "short": "about 120 words",
    "medium": "about 300 words",
    "long": "about 600 words",
}


class GenerateTextIn(BaseModel):
    kind: str = Field(pattern="^(script|story|convert)$")
    prompt: str = Field(min_length=3, max_length=2000)
    niche: str = Field(default="", max_length=80)
    format: str = Field(default="", max_length=40)   # convert target / story length / language hint


class GenerateTextOut(BaseModel):
    text: str
    provider: str
    model: str


@router.post("/generate-text", response_model=GenerateTextOut)
async def generate_text(body: GenerateTextIn, request: Request):
    """Real AI text generation for Script Writer, Story Writer and Content
    Converter. Production AI provider first, free/keyless Pollinations
    fallback — always labeled honestly."""
    _check_rate_limit(request, "generate-text")
    system = _TEXT_SYSTEMS[body.kind]
    user_prompt = body.prompt.strip()
    if body.kind == "story" and body.format:
        length = _TEXT_LENGTHS.get(body.format.lower(), "about 300 words")
        user_prompt += f"\nLength: {length}."
        if "urdu" in body.format.lower():
            user_prompt += " Write in Urdu (Nastaliq-friendly plain Urdu)."
    if body.kind == "convert" and body.format:
        user_prompt = f"Target format: {body.format}\n\nContent to convert:\n{user_prompt}"
    if body.niche:
        user_prompt += f"\nNiche: {body.niche}"
    text, provider_label, model = None, "pollinations", "pollinations-text"
    try:
        provider = get_ai_provider()
        resp = await provider.complete(
            AIRequest(
                agent=f"{body.kind}_writer",
                system=system,
                user=user_prompt,
                max_tokens=1200,
                temperature=0.8,
            )
        )
        if resp.text and not resp.dev:
            text, provider_label, model = resp.text.strip(), resp.provider, resp.model
    except Exception:
        text = None
    if not text:
        text = await _pollinations_text(system, user_prompt)
    if not text:
        raise HTTPException(
            status_code=503,
            detail="AI text generation is unavailable right now. Please try again.",
        )
    return GenerateTextOut(text=text, provider=provider_label, model=model)


async def _pollinations_text(system: str, user_prompt: str) -> str | None:
    """Free/keyless text fallback via Pollinations text API. Returns the raw
    text or None on failure."""
    import urllib.parse

    import httpx

    full = system + "\n\n" + user_prompt
    url = "https://text.pollinations.ai/" + urllib.parse.quote(full[:1500])
    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(120.0, connect=15.0)
        ) as client:
            resp = await client.get(url)
            if resp.status_code != 200:
                return None
            text = resp.text.strip()
            if not text:
                return None
            # Pollinations sometimes wraps the answer in a JSON envelope
            # like {"role":"assistant","reasoning":"...","content":"..."} —
            # extract the real content, never leak the reasoning.
            if text.startswith("{"):
                try:
                    data = json.loads(text)
                except (ValueError, TypeError):
                    data = None
                if isinstance(data, dict):
                    for key in ("content", "text", "answer", "story", "script"):
                        val = data.get(key)
                        if isinstance(val, str) and val.strip():
                            return val.strip()
                    # Fallback: join string values except role/reasoning.
                    parts = [
                        str(v).strip()
                        for k, v in data.items()
                        if k not in ("role", "reasoning", "model")
                        and isinstance(v, str)
                        and v.strip()
                    ]
                    if parts:
                        return "\n\n".join(parts)
                    return None
            return text
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Free MP4 assembly — Ken Burns slideshow from photos (no paid video API)
# ---------------------------------------------------------------------------

class AssembleVideoJson(BaseModel):
    image_urls: list[str] = Field(min_length=2, max_length=8)
    captions: list[str] = Field(default_factory=list)
    seconds_per_scene: float = Field(default=4.0, ge=2.0, le=10.0)


def _ffmpeg_or_503() -> str:
    import shutil

    ff = shutil.which("ffmpeg")
    if not ff:
        raise HTTPException(
            status_code=503,
            detail="Video assembly is not available on this server (ffmpeg missing).",
        )
    return ff


async def _fetch_image(url: str, dest, client) -> bool:
    try:
        r = await client.get(url, timeout=httpx.Timeout(60.0, connect=15.0))
        if r.status_code == 200 and len(r.content) > 1024:
            dest.write_bytes(r.content)
            return True
    except Exception:
        pass
    return False


def _build_slideshow(ff: str, frames: list, captions: list[str], sps: float, out_path) -> None:
    """Ken Burns slideshow -> 720x1280 H.264 MP4. Each frame gets a slow
    zoom-in (zoompan), scenes concatenated."""
    import subprocess

    W, H, FPS = 720, 1280, 30
    seg_files = []
    n = len(frames)
    for i, img in enumerate(frames):
        seg = out_path.parent / f"seg{i}.mp4"
        # Alternate zoom direction for variety; zoompan over sps seconds.
        z_from, z_to = (1.0, 1.12) if i % 2 == 0 else (1.12, 1.0)
        total_frames = int(sps * FPS)
        vf = (
            f"scale=1440:2560:force_original_aspect_ratio=increase,"
            f"crop=1440:2560,"
            f"zoompan=z='min(max(zoom,pzoom)+{((z_to - z_from) / total_frames):.6f},1.5)':"
            f"d={total_frames}:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={W}x{H}:fps={FPS},"
            f"format=yuv420p"
        )
        draw = ""
        cap = captions[i] if i < len(captions) and captions[i].strip() else ""
        if cap:
            safe = cap.replace(":", "\\:").replace("'", "")
            draw = (
                f",drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:"
                f"text='{safe[:60]}':fontcolor=white:fontsize=44:"
                f"x=(w-text_w)/2:y=h-220:shadowcolor=black@0.6:shadowx=2:shadowy=2"
            )
        cmd = [
            ff, "-y", "-loop", "1", "-i", str(img),
            "-vf", vf + draw,
            "-t", str(sps), "-r", str(FPS),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
            "-pix_fmt", "yuv420p", str(seg),
        ]
        r = subprocess.run(cmd, capture_output=True, timeout=300)
        if r.returncode != 0:
            raise RuntimeError(f"ffmpeg scene {i} failed")
        seg_files.append(seg)
    # Concat
    lst = out_path.parent / "list.txt"
    lst.write_text("".join(f"file '{s.name}'\n" for s in seg_files))
    cmd = [ff, "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
           "-c", "copy", str(out_path)]
    r = subprocess.run(cmd, capture_output=True, timeout=120)
    if r.returncode != 0 or not out_path.exists():
        raise RuntimeError("ffmpeg concat failed")


@router.post("/assemble-video")
async def assemble_video(request: Request):
    """Assemble a real vertical MP4 from photos — FREE, no video API key.

    Accepts either JSON {"image_urls": [...], "captions": [...],
    "seconds_per_scene": 4} or multipart form with image files
    (field name "images") + optional "captions" / "seconds_per_scene" fields.
    Returns the MP4 as a direct download response."""
    import tempfile
    from pathlib import Path as _P

    import httpx
    from fastapi import UploadFile
    from fastapi.responses import FileResponse
    from starlette.background import BackgroundTask

    _check_rate_limit(request, "assemble-video")
    ff = _ffmpeg_or_503()
    ctype = request.headers.get("content-type", "")

    captions: list[str] = []
    sps = 4.0
    tmpdir = _P(tempfile.mkdtemp(prefix="vsl_"))
    frames: list[_P] = []

    try:
        if ctype.startswith("multipart/"):
            form = await request.form()
            sps_raw = form.get("seconds_per_scene")
            try:
                sps = max(2.0, min(10.0, float(sps_raw or 4.0)))
            except (TypeError, ValueError):
                sps = 4.0
            cap_raw = form.get("captions")
            if cap_raw:
                captions = [c.strip() for c in str(cap_raw).split("\n")]
            files = [v for v in form.values() if isinstance(v, UploadFile)]
            if not 2 <= len(files) <= 8:
                raise HTTPException(
                    status_code=400,
                    detail="Upload 2 to 8 photos.",
                )
            for i, f in enumerate(files):
                data = await f.read()
                if len(data) > 15 * 1024 * 1024:
                    raise HTTPException(status_code=400, detail="Each photo must be under 15 MB.")
                dest = tmpdir / f"up{i}.jpg"
                dest.write_bytes(data)
                frames.append(dest)
        else:
            try:
                body = AssembleVideoJson.model_validate(await request.json())
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="Send JSON {image_urls:[...]} or multipart images.",
                )
            sps = body.seconds_per_scene
            captions = body.captions
            import httpx as _hx

            async with _hx.AsyncClient() as client:
                for i, url in enumerate(body.image_urls):
                    dest = tmpdir / f"dl{i}.jpg"
                    ok = await _fetch_image(url, dest, client)
                    if ok:
                        frames.append(dest)
            if len(frames) < 2:
                raise HTTPException(
                    status_code=502,
                    detail="Could not download enough images to build the video.",
                )

        # Validate images are decodable (Pillow) so ffmpeg never chokes.
        try:
            from PIL import Image

            good = []
            for fr in frames:
                try:
                    with Image.open(fr) as im:
                        im.verify()
                    good.append(fr)
                except Exception:
                    continue
            frames = good
        except ImportError:
            pass
        if len(frames) < 2:
            raise HTTPException(status_code=400, detail="No usable images found.")

        out_path = tmpdir / "virello-video.mp4"
        _build_slideshow(ff, frames, captions, sps, out_path)

        def _cleanup():
            import shutil as _sh

            _sh.rmtree(tmpdir, ignore_errors=True)

        return FileResponse(
            out_path,
            media_type="video/mp4",
            filename="virello-video.mp4",
            background=BackgroundTask(_cleanup),
        )
    except HTTPException:
        import shutil as _sh

        _sh.rmtree(tmpdir, ignore_errors=True)
        raise
    except Exception as exc:
        import shutil as _sh

        _sh.rmtree(tmpdir, ignore_errors=True)
        raise HTTPException(
            status_code=502, detail=f"Video assembly failed: {str(exc)[:160]}"
        )
