"""Transparent content scoring.

A heuristic assessment of post packaging quality — NOT a prediction of
virality, reach, or sales, and never presented as one. The formula is
documented here so the score is explainable; every component is 0-100.

Components (weights sum to 1.0):
  hook            0.25  opening line has a hook pattern (question/number/power word)
  clarity         0.20  title+caption length in a readable sweet spot
  hashtag_hygiene 0.15  2-8 tags ideal; spammy counts penalized
  media           0.15  thumbnail/video present
  cta             0.10  call-to-action present
  language_fit    0.15  language detectable (audience can read it)
"""
from __future__ import annotations

import re

_HOOK_PATTERNS = re.compile(
    r"^(how|why|what|when|stop|secret|free|new|you|5 |10 |3 |pov|wait|"
    r"[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\u2753\u2754])",
    re.IGNORECASE,
)
_CTA_WORDS = re.compile(
    r"(link in bio|shop now|follow|comment|share|save this|tap|swipe|"
    r"learn more|sign up|get started|visit|check out|dm me|order now)",
    re.IGNORECASE,
)


def _hook(text: str) -> int:
    opening = (text or "").strip()[:60]
    if not opening:
        return 20
    if _HOOK_PATTERNS.search(opening):
        return 95
    if len(opening) >= 20:
        return 65
    return 40


def _clarity(text: str) -> int:
    n = len((text or "").strip())
    if n == 0:
        return 10
    if 40 <= n <= 220:
        return 100
    if n < 40:
        return 55
    if n <= 500:
        return 75
    return 45


def _hashtag_hygiene(count: int) -> int:
    if 2 <= count <= 8:
        return 100
    if count <= 1:
        return 50
    if count <= 15:
        return 60
    return 25


def _media(media_type: str, has_thumbnail: bool) -> int:
    if media_type == "video":
        return 100
    if media_type in ("photo", "rich"):
        return 85
    if has_thumbnail:
        return 70
    if media_type == "link":
        return 55
    return 30


def _cta(text: str) -> int:
    return 100 if _CTA_WORDS.search(text or "") else 40


def _language_fit(language: str) -> int:
    return 100 if language in ("en", "ur", "ar") else 50


WEIGHTS = {
    "hook": 0.25, "clarity": 0.20, "hashtag_hygiene": 0.15,
    "media": 0.15, "cta": 0.10, "language_fit": 0.15,
}

DISCLAIMER = (
    "Heuristic packaging assessment — an estimate of how well the post is "
    "presented, not a prediction or guarantee of reach, virality, or sales."
)


def score_content(*, title: str, description: str, hashtag_count: int,
                  media_type: str, has_thumbnail: bool,
                  language: str) -> dict:
    text = f"{title or ''}\n{description or ''}".strip()
    components = {
        "hook": _hook(text),
        "clarity": _clarity(text),
        "hashtag_hygiene": _hashtag_hygiene(hashtag_count),
        "media": _media(media_type, has_thumbnail),
        "cta": _cta(text),
        "language_fit": _language_fit(language),
    }
    total = round(sum(components[k] * w for k, w in WEIGHTS.items()))
    return {"score": total, "components": components,
            "weights": WEIGHTS, "disclaimer": DISCLAIMER}
