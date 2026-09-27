"""Multilingual language API — detection, concepts, expansion, packs.

- GET / ................ list all supported languages (selector metadata:
  code, native/English names, scripts, RTL, UI translation status,
  pack quality — draft packs need native-speaker review).
- POST /detect ......... detect language of text (primary, script,
  confidence, alternatives, mixed/transliteration flags, uncertainty).
- POST /analyze ........ full analysis: detection + cross-language concept
  IDs + embedder backend in use.
- GET /embedder ......... which embedding backend is active (heuristic vs
  neural) and what is still pending.
- POST /expand .......... recommend additional language audiences for
  content languages + concepts, each with a reason (suggestions only).

Uncertain detections are flagged in the response — callers must surface
them, never silently treat them as certain.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.deps import get_current_user
from app.models.core import User
from app.services import language as lang_svc
from app.services.language import (concept_ids_for_text, describe_languages,
                                   detect, embedder_status, get_pack,
                                   is_supported, recommend_languages,
                                   topic_name)

router = APIRouter()


@router.get("")
async def list_languages(_user: User = Depends(get_current_user)) -> dict:
    langs = describe_languages()
    return {
        "languages": langs,
        "count": len(langs),
        "note": ("ui_status 'full' = complete UI translation; 'partial' = "
                 "English fallback for untranslated strings. pack_quality "
                 "'draft' = detection data needs native-speaker review."),
    }


class TextIn(BaseModel):
    text: str


@router.post("/detect")
async def detect_language(body: TextIn,
                          _user: User = Depends(get_current_user)) -> dict:
    if not body.text or not body.text.strip():
        raise HTTPException(400, "text is required.")
    if len(body.text) > 20000:
        raise HTTPException(400, "text too long (max 20000 chars).")
    return {"detection": detect(body.text).to_dict()}


@router.post("/analyze")
async def analyze_text(body: TextIn,
                       _user: User = Depends(get_current_user)) -> dict:
    if not body.text or not body.text.strip():
        raise HTTPException(400, "text is required.")
    if len(body.text) > 20000:
        raise HTTPException(400, "text too long (max 20000 chars).")
    detection = detect(body.text).to_dict()
    concepts = concept_ids_for_text(body.text)
    emb = lang_svc.get_embedder()
    primary = detection["primary"]
    return {
        "detection": detection,
        "concepts": concepts,
        "concept_names": {c: topic_name(c, primary) for c in concepts},
        "embedding": {
            **emb.describe(),
            "vector_preview": emb.embed(body.text[:500], primary)[:8],
        },
        "honesty": ("concepts are shared IDs across languages, not "
                    "translations; uncertain detections must be surfaced "
                    "in the UI"),
    }


@router.get("/embedder")
async def embedder_info(
        _user: User = Depends(get_current_user)) -> dict:
    return embedder_status()


class ExpandIn(BaseModel):
    languages: list[str]
    concepts: list[str] = []
    segments: list[dict] = []
    limit: int = 5


@router.post("/expand")
async def expand_languages(body: ExpandIn,
                           _user: User = Depends(get_current_user)) -> dict:
    langs = [str(c).strip().lower() for c in body.languages][:8]
    for code in langs:
        if not is_supported(code):
            raise HTTPException(400, f"Unsupported language: {code}.")
    if not langs:
        raise HTTPException(400, "languages is required.")
    recs = recommend_languages(langs, body.concepts[:8],
                               body.segments[:50],
                               limit=max(1, min(body.limit, 10)))
    return {
        "recommendations": recs,
        "disclaimer": ("Suggestions with explanations — not audience-size "
                       "claims and not performance guarantees."),
    }


@router.get("/notify/events")
async def notify_events(
        _user: User = Depends(get_current_user)) -> dict:
    from app.services.language import (TEMPLATES,
                                       available_template_languages)
    return {
        "events": {e: available_template_languages(e) for e in TEMPLATES},
        "note": ("Template languages are the only ones rendered; every "
                 "other language falls back to English with "
                 "fallback_used=true."),
    }


class NotifyPreviewIn(BaseModel):
    event: str
    language: str = "en"
    params: dict = {}


@router.post("/notify/preview")
async def notify_preview(body: NotifyPreviewIn,
                         _user: User = Depends(get_current_user)) -> dict:
    from app.services.language import render_notification
    try:
        return render_notification(body.event, body.language, body.params)
    except KeyError:
        raise HTTPException(400, f"Unknown event: {body.event}.")


@router.get("/{code}")
async def language_detail(code: str,
                          _user: User = Depends(get_current_user)) -> dict:
    pack = get_pack(code.strip().lower())
    if pack is None:
        raise HTTPException(404, "Unsupported language.")
    return {
        "code": pack.code,
        "iso_639_3": pack.iso_639_3,
        "name_en": pack.name_en,
        "name_native": pack.name_native,
        "scripts": pack.scripts,
        "rtl": pack.rtl,
        "regions": pack.regions,
        "ui_status": pack.ui_status,
        "pack_quality": pack.pack_quality,
        "transliteration_variants": pack.transliteration_variants,
        "related_languages": [{"code": r.code, "reason": r.reason}
                              for r in pack.related()],
        "notes": pack.notes,
    }
