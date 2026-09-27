"""Feature extraction: platform, hashtags, mentions, language, signals."""
from __future__ import annotations

import re
from urllib.parse import urlparse

from app.services.language import (concept_ids_for_text, detect,
                                   hashtag_to_concepts)

_HASHTAG = re.compile(r"#(\w{2,60})", re.UNICODE)
_MENTION = re.compile(r"@(\w{2,40})", re.UNICODE)

# Urdu-specific characters (not shared with Arabic).
_URDU_CHARS = set("ٹڈڑںھےۃ")
_ARABIC_BLOCK = re.compile(r"[\u0600-\u06FF]")


def detect_platform(url: str) -> str:
    host = (urlparse(url).hostname or "").lower()
    if "tiktok.com" in host:
        return "tiktok"
    if "instagram.com" in host:
        return "instagram"
    if "youtube.com" in host or "youtu.be" in host:
        return "youtube"
    if "x.com" in host or "twitter.com" in host:
        return "x"
    if "facebook.com" in host or "fb.watch" in host:
        return "facebook"
    return "unknown"


def extract_hashtags(text: str) -> list[str]:
    seen: list[str] = []
    for tag in _HASHTAG.findall(text or ""):
        t = tag.lower()
        if t not in seen:
            seen.append(t)
    return seen[:30]


def extract_mentions(text: str) -> list[str]:
    seen: list[str] = []
    for m in _MENTION.findall(text or ""):
        name = m.lower()
        if name not in seen:
            seen.append(name)
    return seen[:30]


def detect_language(text: str) -> str:
    """Primary language code via the multilingual detector.

    Backed by app.services.language.detect (script profile + seeded
    offline langdetect + pack dictionaries + transliteration handling).
    Use analyze_language_full() when you need confidence, alternatives,
    mixed-language / transliteration metadata, and uncertainty flags.
    """
    return detect(text or "").primary


def analyze_language_full(text: str) -> dict:
    """Full language analysis: detection result dict + concept IDs.

    ``concepts`` are canonical topic slugs found in ANY supported
    language — the basis for cross-language matching (never translated
    word-for-word). ``detection_uncertain`` must be surfaced in the UI,
    never silently treated as certain.
    """
    text = text or ""
    result = detect(text)
    concepts = concept_ids_for_text(text)
    for tag in extract_hashtags(text):
        for slug in hashtag_to_concepts(tag):
            if slug not in concepts:
                concepts.append(slug)
    payload = result.to_dict()
    payload["concepts"] = concepts[:8]
    return payload


def normalize_url(url: str) -> str:
    """Lowercase host, drop tracking params (utm_*, fbclid, gclid...)."""
    from urllib.parse import parse_qsl, urlencode, urlunparse

    parsed = urlparse(url.strip())
    host = (parsed.hostname or "").lower()
    keep = [(k, v) for k, v in parse_qsl(parsed.query)
            if not k.lower().startswith(("utm_", "fbclid", "gclid", "mc_"))]
    netloc = host + (f":{parsed.port}" if parsed.port else "")
    return urlunparse((parsed.scheme or "https", netloc, parsed.path or "/",
                       "", urlencode(keep), ""))
