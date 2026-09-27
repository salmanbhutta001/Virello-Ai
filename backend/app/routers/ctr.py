"""Link CTR optimizer — free organic growth strategy #6.

Audits a public link's OpenGraph/meta tags against a factual checklist
(page title length, meta description, og:title/og:description, og:image,
twitter:card, canonical URL) and proposes AI-written title/description fixes.

Deliberately NO 0-100 "CTR score": every check is factual pass/warn/fail
with the actual measured value, and any single score would be misleading.

SSRF safety: all fetching goes through ``app.services.analysis.fetcher``
(``fetch_post`` plus its ``_client``/``_safe_get`` building blocks, which
re-validate every redirect hop against the SSRF blocklist). This module
never issues direct ``requests``/httpx calls to the user-supplied URL.
"""
from __future__ import annotations

import html
import json
import re
import struct
from typing import Any
from urllib.parse import urljoin, urlparse

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.core.deps import get_current_user
from app.models.core import User
from app.services.analysis.extract import detect_platform
from app.services.analysis.fetcher import _client, _safe_get, _url_is_safe, fetch_post
from app.services.ai.base import (
    AIProvider,
    AIProviderError,
    AIProviderNotConfigured,
    AIRequest,
    get_ai_provider,
)

router = APIRouter()

# ---------------------------------------------------------------------------
# Meta-tag extraction (raw HTML via the fetcher's SSRF-safe machinery)


_TAG_RE = re.compile(r"<meta\s+([^>]*?)\s*/?>", re.IGNORECASE | re.DOTALL)
_ATTR_RE = re.compile(r"""([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))""")
_LINK_RE = re.compile(r"<link\s+([^>]*?)\s*/?>", re.IGNORECASE | re.DOTALL)
_TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)


def _attrs(tag_body: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for m in _ATTR_RE.finditer(tag_body or ""):
        out[m.group(1).lower()] = html.unescape(
            m.group(2) or m.group(3) or m.group(4) or "")
    return out


def _clean(text: str) -> str:
    return html.unescape(re.sub(r"\s+", " ", text or "").strip())


def _extract_meta(page_html: str) -> dict[str, str]:
    """Pull the CTR-relevant tags out of raw HTML. Missing tags stay ""."""
    meta = {"title": "", "description": "", "og_title": "",
            "og_description": "", "og_image": "", "twitter_card": "",
            "canonical": ""}
    m = _TITLE_RE.search(page_html or "")
    if m:
        meta["title"] = _clean(re.sub(r"<[^>]+>", "", m.group(1)))
    for tag in _TAG_RE.finditer(page_html or ""):
        a = _attrs(tag.group(1))
        key = (a.get("property") or a.get("name") or "").lower()
        content = _clean(a.get("content", ""))
        if not content:
            continue
        if key == "description" and not meta["description"]:
            meta["description"] = content
        elif key == "og:title" and not meta["og_title"]:
            meta["og_title"] = content
        elif key == "og:description" and not meta["og_description"]:
            meta["og_description"] = content
        elif key == "og:image" and not meta["og_image"]:
            meta["og_image"] = content
        elif key == "twitter:card" and not meta["twitter_card"]:
            meta["twitter_card"] = content
    for tag in _LINK_RE.finditer(page_html or ""):
        a = _attrs(tag.group(1))
        if a.get("rel", "").lower() == "canonical" and a.get("href"):
            meta["canonical"] = _clean(a["href"])
            break
    return meta


async def _fetch_html(url: str) -> str | None:
    """Raw HTML through the fetcher's SSRF-safe machinery (never raw requests)."""
    try:
        async with _client() as client:
            resp = await _safe_get(client, url)
            if resp is None:
                return None
            body = b""
            async for chunk in resp.aiter_bytes(65536):
                body += chunk
                if len(body) > 2 * 1024 * 1024:  # same 2 MB cap as fetch_post
                    break
        text = body.decode("utf-8", errors="ignore")
        return text if text.strip() else None
    except Exception:
        return None


# ---------------------------------------------------------------------------
# og:image probing (fail-safe: never raises, never fails the audit)


def _image_dimensions(data: bytes) -> tuple[int, int] | None:
    """Best-effort width/height sniff for PNG/GIF/JPEG/WebP. None = unknown."""
    try:
        if data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) >= 24:
            w, h = struct.unpack(">II", data[16:24])
            return w, h
        if data[:6] in (b"GIF87a", b"GIF89a") and len(data) >= 10:
            w, h = struct.unpack("<HH", data[6:10])
            return w, h
        if data[:2] == b"\xff\xd8":  # JPEG: scan for a Start-Of-Frame marker
            i = 2
            while i + 9 < len(data):
                if data[i] != 0xFF:
                    break
                marker = data[i + 1]
                if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                              0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    h, w = struct.unpack(">HH", data[i + 5:i + 9])
                    return w, h
                seg_len = struct.unpack(">H", data[i + 2:i + 4])[0]
                if seg_len < 2:
                    break
                i += 2 + seg_len
        if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            if data[12:16] == b"VP8 " and len(data) >= 30:
                w = struct.unpack("<H", data[26:28])[0] & 0x3FFF
                h = struct.unpack("<H", data[28:30])[0] & 0x3FFF
                return w, h
            if data[12:16] == b"VP8L" and len(data) >= 25:
                bits = struct.unpack("<I", data[21:25])[0]
                return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    except Exception:
        return None
    return None


async def _probe_image(url: str) -> tuple[str, tuple[int, int] | None] | None:
    """Fetch an image URL SSRF-safely; returns (content-type, dims) or None."""
    try:
        async with _client() as client:
            resp = await _safe_get(client, url)
            if resp is None:
                return None
            content_type = resp.headers.get("content-type", "")
            data = b""
            async for chunk in resp.aiter_bytes(65536):
                data += chunk
                if len(data) > 65536:  # header bytes are enough for dims
                    break
        return content_type, _image_dimensions(data)
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Factual checklist


def _check(name: str, status: str, detail: str, fix_hint: str) -> dict:
    return {"check": name, "status": status, "detail": detail,
            "fix_hint": fix_hint}


def _title_check(title: str) -> dict:
    if not title:
        return _check("page_title", "fail", "No <title> tag found.",
                      "Add a <title> of 40\u201360 characters that states "
                      "what the page is about.")
    n = len(title)
    if 40 <= n <= 60:
        return _check("page_title", "pass",
                      f"Title present ({n} chars): \u201c{title}\u201d.",
                      "No change needed.")
    if n < 40:
        return _check("page_title", "warn",
                      f"Title is only {n} chars: \u201c{title}\u201d.",
                      "Extend it to 40\u201360 characters with one clear "
                      "keyword phrase \u2014 short titles get truncated less "
                      "but earn fewer clicks.")
    return _check("page_title", "warn",
                  f"Title is {n} chars (over 60): \u201c{title}\u201d.",
                  "Trim it to 40\u201360 characters \u2014 search and social "
                  "feeds cut off longer titles.")


def _description_check(description: str) -> dict:
    if not description:
        return _check("meta_description", "fail",
                      "No meta description found.",
                      "Add <meta name=\"description\"> of 120\u2013160 "
                      "characters summarising the page honestly.")
    n = len(description)
    if 120 <= n <= 160:
        return _check("meta_description", "pass",
                      f"Meta description present ({n} chars).",
                      "No change needed.")
    if n < 120:
        return _check("meta_description", "warn",
                      f"Meta description is only {n} chars.",
                      "Expand it to 120\u2013160 characters \u2014 a fuller "
                      "snippet wins more clicks.")
    return _check("meta_description", "warn",
                  f"Meta description is {n} chars (over 160).",
                  "Trim it to 120\u2013160 characters \u2014 feeds truncate "
                  "the rest.")


def _og_tags_check(og_title: str, og_description: str) -> dict:
    if og_title and og_description:
        return _check("og_tags", "pass",
                      "og:title and og:description are both present.",
                      "No change needed.")
    missing = [t for t, v in (("og:title", og_title),
                              ("og:description", og_description)) if not v]
    if og_title or og_description:
        return _check("og_tags", "warn",
                      f"Missing {', '.join(missing)}.",
                      f"Add <meta property=\"{missing[0]}\" ...> so shares "
                      "render a proper headline and snippet.")
    return _check("og_tags", "fail",
                  "Neither og:title nor og:description found.",
                  "Add both <meta property=\"og:title\"> and "
                  "<meta property=\"og:description\"> \u2014 without them, "
                  "shares show a bare URL.")


async def _og_image_check(image_url: str, page_url: str) -> dict:
    if not image_url:
        return _check("og_image", "fail", "No og:image tag found.",
                      "Add <meta property=\"og:image\" "
                      "content=\"https://...\u201d> with an image at least "
                      "1200\u00d7630 px \u2014 links with images get far more "
                      "clicks.")
    resolved = urljoin(page_url, image_url)
    if not await _url_is_safe(resolved):
        return _check("og_image", "warn",
                      f"og:image URL could not be resolved safely: {resolved}",
                      "Host the image on a public HTTPS URL.")
    probed = await _probe_image(resolved)
    if probed is None:
        return _check("og_image", "warn",
                      "og:image is present but the image could not be "
                      "fetched to verify it.",
                      "Open the image URL yourself and confirm it loads; "
                      "use at least 1200\u00d7630 px.")
    _content_type, dims = probed
    if dims and dims[0] >= 1200 and dims[1] >= 630:
        return _check("og_image", "pass",
                      f"og:image resolves ({dims[0]}\u00d7{dims[1]} px).",
                      "No change needed.")
    if dims:
        return _check("og_image", "warn",
                      f"og:image is {dims[0]}\u00d7{dims[1]} px \u2014 below "
                      "the recommended 1200\u00d7630.",
                      "Use a 1200\u00d7630 px (or larger) image so the "
                      "preview fills the card.")
    return _check("og_image", "warn",
                  "og:image resolves but its dimensions could not be "
                  "determined.",
                  "Confirm the image is at least 1200\u00d7630 px.")


def _twitter_card_check(card: str) -> dict:
    if not card:
        return _check("twitter_card", "fail", "No twitter:card tag found.",
                      "Add <meta name=\"twitter:card\" "
                      "content=\"summary_large_image\"> for a large preview "
                      "on X/Twitter.")
    if card.lower() == "summary_large_image":
        return _check("twitter_card", "pass",
                      "twitter:card is summary_large_image.",
                      "No change needed.")
    return _check("twitter_card", "warn",
                  f"twitter:card is \u201c{card}\u201d, not "
                  "summary_large_image.",
                  "Switch to summary_large_image for the large-image preview.")


def _canonical_check(canonical: str) -> dict:
    if canonical:
        return _check("canonical", "pass",
                      f"Canonical URL present: {canonical}",
                      "No change needed.")
    return _check("canonical", "warn", "No canonical URL found.",
                  "Add <link rel=\"canonical\" href=\"...\"> so shares and "
                  "search consolidate on one URL.")


# ---------------------------------------------------------------------------
# AI fix suggestions (strict JSON + heuristic fallback, growth_ai.py pattern)


_CTR_SYSTEM = (
    "You are Virello's Link CTR assistant. You rewrite page titles and meta "
    "descriptions so shared links earn honest clicks in feeds and search "
    "results.\n"
    "STRICT HONESTY RULES (violate none of these):\n"
    "1. Never suggest fake engagement, bots, click farms, or artificial "
    "accounts.\n"
    "2. Never guarantee clicks, traffic, followers, or sales. Your output is "
    "suggestions only \u2014 label nothing as a promise.\n"
    "3. Stay faithful to what the page is actually about \u2014 never invent "
    "claims, offers, or facts not evident from the given title/description/URL.\n"
    "4. Respond with ONLY a single JSON object matching the schema below. "
    "No prose, no markdown fences, no commentary."
)

_CTR_SCHEMA_HINT = """\
{"titles": ["string, max 60 chars", "string, max 60 chars", "string, max 60 chars"],
 "descriptions": ["string, max 160 chars", "string, max 160 chars", "string, max 160 chars"]}
Constraints: EXACTLY 3 titles and EXACTLY 3 descriptions."""


def _ctr_user_prompt(title: str, description: str, url: str) -> str:
    return (
        f"Page URL: {url}\n"
        f"Current title: {title or '(missing)'}\n"
        f"Current meta description: {description or '(missing)'}\n\n"
        "Propose 3 improved titles (max 60 characters each) and 3 improved "
        "meta descriptions (max 160 characters each).\n"
        f"Schema:\n{_CTR_SCHEMA_HINT}"
    )


class _SchemaViolation(ValueError):
    """Provider JSON failed the strict CTR schema."""


def _strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else ""
        if text.rstrip().endswith("```"):
            text = text.rstrip()[:-3]
    return text.strip()


def _validate_ctr(payload: Any) -> dict:
    if not isinstance(payload, dict):
        raise _SchemaViolation("expected a JSON object")
    out: dict[str, list[str]] = {}
    for key, want, max_len in (("titles", 3, 60), ("descriptions", 3, 160)):
        items = payload.get(key)
        if not isinstance(items, list) or len(items) != want:
            raise _SchemaViolation(f"{key}: expected exactly {want} items")
        clean: list[str] = []
        for i, item in enumerate(items):
            if not isinstance(item, str):
                raise _SchemaViolation(f"{key}[{i}]: expected string")
            text = item.strip()
            if not (1 <= len(text) <= max_len):
                raise _SchemaViolation(
                    f"{key}[{i}]: length {len(text)} outside 1..{max_len}")
            clean.append(text)
        out[key] = clean
    return out


async def ctr_fixes_via_ai(title: str, description: str, url: str,
                           provider: AIProvider | None = None) -> dict | None:
    """Ask the AI provider for title/description fixes as strict JSON.

    Returns ``{"titles": [...], "descriptions": [...]}`` or None on ANY
    failure so the caller falls back to heuristics. Never raises.
    """
    try:
        p = provider or get_ai_provider()
        resp = await p.complete(AIRequest(
            agent="ctr_optimizer", system=_CTR_SYSTEM,
            user=_ctr_user_prompt(title or "", description or "", url),
            max_tokens=800, temperature=0.5, json_mode=True,
            metadata={"ctr_audit": True},
        ))
        payload = json.loads(_strip_fences(resp.text or ""))
        return _validate_ctr(payload)
    except (AIProviderNotConfigured, AIProviderError, ValueError,
            AttributeError, TypeError, KeyError):
        return None


# ---------------------------------------------------------------------------
# Heuristic fallback (deterministic, honestly labeled)


def _word_trim(text: str, limit: int) -> str:
    text = " ".join((text or "").split())
    if len(text) <= limit:
        return text
    cut = text[:limit - 1].rsplit(" ", 1)
    head = cut[0] if cut[0] else text[:limit - 1]
    return head.rstrip(" ,;:\u2014-") + "\u2026"


def _sentence_trim(text: str, limit: int) -> str:
    text = " ".join((text or "").split())
    if len(text) <= limit:
        return text
    out = ""
    for s in re.split(r"(?<=[.!?])\s+", text):
        candidate = (out + " " + s).strip()
        if len(candidate) <= limit:
            out = candidate
        else:
            break
    return out or _word_trim(text, limit)


def _slug_to_words(url: str) -> str:
    path = urlparse(url).path.strip("/")
    seg = path.split("/")[-1] if path else ""
    words = re.sub(r"\.\w+$", "", re.sub(r"[-_]+", " ", seg)).strip()
    return words.title() or urlparse(url).netloc.replace("www.", "")


def _dedupe(items: list[str]) -> list[str]:
    out: list[str] = []
    for item in items:
        if item and item not in out:
            out.append(item)
    return out


def _heuristic_fixes(title: str, description: str, url: str) -> dict:
    """Deterministic title/description options from the page's own text.

    Labeled ``"heuristic"`` in the response \u2014 these are mechanical
    trims/rewrites, not AI writing, and never invent page content.
    """
    domain = urlparse(url).netloc.replace("www.", "")
    base_t = (title or "").strip() or _slug_to_words(url)
    base_d = (description or "").strip()

    t1 = _word_trim(base_t, 60)
    t2 = _word_trim(f"{base_t} | {domain}", 60)
    t3 = _word_trim(" ".join(base_t.split()[:12]), 60)
    titles = _dedupe([t1, t2, t3])
    fillers = [_word_trim(f"{t1} \u2014 read more", 60),
               _word_trim(f"{domain}: {base_t}", 60)]
    for f in fillers:
        if len(titles) >= 3:
            break
        if f not in titles:
            titles.append(f)
    titles = titles[:3]

    if base_d:
        d1 = _sentence_trim(base_d, 160)
        d2 = _word_trim(base_d, 160)
        d3 = _word_trim(f"{d1} More at {domain}.", 160)
        descriptions = _dedupe([d1, d2, d3])
        while len(descriptions) < 3:
            descriptions.append(_word_trim(base_d, 150) + "\u2026")
        descriptions = descriptions[:3]
    else:
        stub = _word_trim(f"{base_t}.", 160)
        descriptions = _dedupe([
            stub,
            "Write one clear sentence about this page (keep it under 160 "
            "characters).",
            _word_trim(f"{base_t} \u2014 {domain}.", 160),
        ])[:3]

    return {
        "titles": [{"text": t, "length": len(t)} for t in titles],
        "descriptions": [{"text": d, "length": len(d)} for d in descriptions],
    }


def _shape_suggestions(fixes: dict) -> dict:
    return {
        "titles": [{"text": t, "length": len(t)} for t in fixes["titles"]],
        "descriptions": [{"text": d, "length": len(d)}
                         for d in fixes["descriptions"]],
    }


# ---------------------------------------------------------------------------
# Endpoint


class CtrAuditIn(BaseModel):
    url: str


@router.post("/ctr-audit")
async def ctr_audit(body: CtrAuditIn,
                    user: User = Depends(get_current_user)) -> dict:
    """Factual OpenGraph/meta audit + AI fix suggestions for a public link.

    No 0-100 score \u2014 the response is a factual checklist plus a
    pass/warn/fail count summary. Unfetchable or tag-less pages return
    422; nothing is ever fabricated.
    """
    raw = (body.url or "").strip()
    parsed = urlparse(raw)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise HTTPException(
            422, "That doesn't look like a valid public link. "
                 "Paste a full http(s) URL.")

    platform = detect_platform(raw)
    try:
        res = await fetch_post(raw, platform)
    except Exception:
        raise HTTPException(
            422, "We couldn't reach that page right now. "
                 "Check the link and try again.")
    page_html = await _fetch_html(raw)
    if page_html is None:
        raise HTTPException(
            422, "We couldn't reach that page right now. "
                 "Check the link and try again.")

    meta = _extract_meta(page_html)
    # fetch_post's battle-tested OG parser backfills anything the tag-level
    # regex missed (attribute order variants, oEmbed pages).
    if not meta["og_title"] and res.title:
        meta["og_title"] = res.title
    if not meta["og_description"] and res.description:
        meta["og_description"] = res.description
    if not meta["og_image"] and res.thumbnail_url:
        meta["og_image"] = res.thumbnail_url

    if not any((meta["title"], meta["description"], meta["og_title"],
                meta["og_description"], meta["og_image"])):
        raise HTTPException(
            422, "No readable title or meta tags were found on that page. "
                 "Nothing was fabricated \u2014 try the original page instead.")

    checks = [
        _title_check(meta["title"]),
        _description_check(meta["description"]),
        _og_tags_check(meta["og_title"], meta["og_description"]),
        await _og_image_check(meta["og_image"], raw),
        _twitter_card_check(meta["twitter_card"]),
        _canonical_check(meta["canonical"]),
    ]
    n_pass = sum(1 for c in checks if c["status"] == "pass")
    n_warn = sum(1 for c in checks if c["status"] == "warn")
    n_fail = sum(1 for c in checks if c["status"] == "fail")

    ai_fixes = await ctr_fixes_via_ai(meta["title"] or meta["og_title"],
                                      meta["description"] or meta["og_description"],
                                      raw)
    if ai_fixes is not None:
        source = "ai"
        suggestions = _shape_suggestions(ai_fixes)
    else:
        source = "heuristic"
        suggestions = _heuristic_fixes(meta["title"] or meta["og_title"],
                                       meta["description"] or meta["og_description"],
                                       raw)

    return {
        "url": raw,
        "domain": parsed.netloc.replace("www.", ""),
        "extracted": meta,
        "checks": checks,
        "summary": {
            "pass": n_pass, "warn": n_warn, "fail": n_fail,
            "text": f"{n_pass} pass, {n_warn} warn, {n_fail} fail",
        },
        "suggestions": {"source": source, **suggestions},
    }
