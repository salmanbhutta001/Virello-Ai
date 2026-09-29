"""Intent classification for Ask Virello — deterministic keyword heuristic v1.

Multilingual (EN/UR/AR). Matching is done on word tokens (not substrings)
to avoid false positives like "building" matching "build". Every result is
labeled with the method name so callers can mark output as heuristic.

Intents map onto existing Virello modules; the unbuilt vision module
(commerce) is routed to an honest "coming soon" response — never faked.
(Academy and entertainment went live in Phases 5 and 6.)
"""
from __future__ import annotations

import re

# Public intent vocabulary.
CREATE_CONTENT = "create_content"
ANALYZE_CONTENT = "analyze_content"
GROW = "grow"
DISCOVER = "discover"
SHOP = "shop"
LEARN = "learn"
ENTERTAIN = "entertain"
SUPPORT = "support"
UNKNOWN = "unknown"

INTENTS = (
    CREATE_CONTENT,
    ANALYZE_CONTENT,
    GROW,
    DISCOVER,
    SHOP,
    LEARN,
    ENTERTAIN,
    SUPPORT,
    UNKNOWN,
)

METHOD = "keyword-heuristic-v1"

# Each intent maps to the Virello module that serves it.
MODULES: dict[str, dict] = {
    CREATE_CONTENT: {
        "module": "creator",
        "status": "live",
        "phase": 3,
        "served_by": "AI provider (heuristic/dev fallback until a production provider is configured)",
    },
    ANALYZE_CONTENT: {
        "module": "analysis",
        "status": "live",
        "endpoint": "POST /api/v1/analysis/analyze",
        "served_by": "post/video analysis engine",
    },
    GROW: {
        "module": "growth",
        "status": "live",
        "endpoint": "POST /api/v1/growth/loops",
        "served_by": "AI Growth Orchestrator (10 agents) + growth loop v1",
    },
    DISCOVER: {
        "module": "discovery",
        "status": "live",
        "endpoint": "GET /api/v1/discovery/feed",
        "served_by": "discovery feed + trending + AI picks",
    },
    SHOP: {
        "module": "commerce",
        "status": "live",
        "phase": 4,
        "endpoint": "GET /api/v1/commerce/products",
        "served_by": "Shop catalog (real products, affiliate disclosure)",
    },
    LEARN: {
        "module": "academy",
        "status": "live",
        "endpoint": "GET /api/v1/academy/lessons",
        "served_by": "AI Academy (lessons, quizzes, progress)",
    },
    ENTERTAIN: {
        "module": "entertainment",
        "status": "live",
        "endpoint": "POST /api/v1/entertain/story",
        "served_by": "AI story/comic generator (dev-labeled)",
    },
    SUPPORT: {
        "module": "support",
        "status": "live",
        "endpoint": "POST /api/v1/ai/support",
        "served_by": "AI Support",
    },
    UNKNOWN: {
        "module": "support",
        "status": "live",
        "endpoint": "POST /api/v1/ai/support",
        "served_by": "AI Support",
    },
}

# Keyword sets per intent per language. Matched against word tokens.
_KEYWORDS: dict[str, dict[str, tuple[str, ...]]] = {
    CREATE_CONTENT: {
        "en": ("create", "make", "write", "generate", "idea", "ideas", "script",
               "caption", "hook", "thumbnail", "compose", "draft"),
        "ur": ("banao", "banayo", "likho", "likh", "idea", "ideaz", "script",
               "caption", "takhleeq", "tasveer"),
        "ar": ("انشئ", "اكتب", "فكرة", "افكار", "نص", "تسمية", "صورة", "فيديو", "منشور"),
    },
    ANALYZE_CONTENT: {
        "en": ("analyze", "analysis", "analyse", "review", "audit", "score",
               "improve", "improvement", "viral", "evaluate", "check", "feedback"),
        "ur": ("analyze", "tajziya", "jaiza", "behtar", "score", "viral", "check"),
        "ar": ("حلل", "تحليل", "راجع", "قيّم", "نقاط", "تحسين"),
    },
    GROW: {
        "en": ("grow", "growth", "boost", "promote", "campaign", "advertise",
               "audience", "reach", "marketing", "launch"),
        "ur": ("grow", "barhao", "campaign", "muhim", "audience", "reach",
               "boost", "taraqqi"),
        "ar": ("نمو", "روج", "حملة", "جمهور", "وصول", "إعلان", "تسويق"),
    },
    DISCOVER: {
        "en": ("discover", "trending", "trend", "feed", "explore", "find",
               "recommend", "suggest", "picks", "for you"),
        "ur": ("discover", "trending", "daryaft", "talash", "feed", "dekho"),
        "ar": ("اكتشف", "رائج", "خلاصة", "استكشف", "اقتراح", "توصية"),
    },
    SHOP: {
        "en": ("shop", "buy", "purchase", "product", "price", "deal", "store",
               "cart", "compare", "sell"),
        "ur": ("kharido", "khareed", "dukkan", "product", "qeemat", "becho", "deal"),
        "ar": ("تسوق", "اشتر", "منتج", "سعر", "متجر", "بيع", "عرض"),
    },
    LEARN: {
        "en": ("learn", "teach", "tutorial", "lesson", "course", "quiz",
               "explain", "how to", "guide"),
        "ur": ("seekho", "sikhao", "sabaq", "tutorial", "samjhao", "kaise"),
        "ar": ("تعلم", "علمني", "درس", "دورة", "اختبار", "اشرح", "كيف"),
    },
    ENTERTAIN: {
        "en": ("story", "stories", "comic", "fun", "entertain", "game", "meme", "joke"),
        "ur": ("kahani", "mazah", "fun", "khel", "latifa"),
        "ar": ("قصة", "قصص", "مرح", "ترفيه", "لعبة", "نكتة"),
    },
    SUPPORT: {
        "en": ("help", "support", "how does", "what is virello", "plan", "pricing",
               "payment", "billing", "account", "problem", "issue", "error", "not working"),
        "ur": ("madad", "help", "masla", "payment", "plan", "account", "kaam"),
        "ar": ("مساعدة", "دعم", "مشكلة", "خطأ", "دفع", "حساب", "خطة"),
    },
}

_URL_RE = re.compile(r"https?://|www\.", re.IGNORECASE)
_WORD_RE = re.compile(r"[^\w\u0600-\u06FF]+", re.UNICODE)


def _tokens(text: str) -> set[str]:
    """Word tokens (unicode-aware, keeps Arabic script)."""
    return {t for t in _WORD_RE.split(text.lower()) if t}


def _score_intent(tokens: set[str], lowered: str, intent: str, language: str) -> int:
    langs = _KEYWORDS.get(intent, {})
    kws = langs.get(language, ()) + langs.get("en", ())
    hits = 0
    for kw in kws:
        if " " in kw:
            if kw in lowered:  # multi-word phrases: substring on lowered text
                hits += 1
        elif kw in tokens:
            hits += 1
    return hits


def _confidence(hits: int) -> float:
    if hits <= 0:
        return 0.0
    return round(min(0.95, 0.45 + 0.15 * hits), 2)


def classify_intent(text: str, language: str = "en") -> tuple[str, float]:
    """Classify one input → (intent, confidence).

    Deterministic keyword heuristic v1. A URL in the text boosts
    analyze_content (Viral Lab). No match → ("unknown", 0.0).
    """
    lang = (language or "en").lower()
    if lang not in ("en", "ur", "ar"):
        lang = "en"
    lowered = text.lower()
    tokens = _tokens(text)

    scores = {intent: _score_intent(tokens, lowered, intent, lang)
              for intent in INTENTS if intent != UNKNOWN}
    if _URL_RE.search(text):
        scores[ANALYZE_CONTENT] = scores.get(ANALYZE_CONTENT, 0) + 2

    best = max(scores, key=lambda k: scores[k])
    hits = scores[best]
    if hits <= 0:
        return UNKNOWN, 0.0
    return best, _confidence(hits)


def detect_intents(
    text: str, language: str = "en", threshold: float = 0.45
) -> list[tuple[str, float]]:
    """All intents scoring above threshold, best-first.

    Used for multi-module chaining, e.g. "create a post and grow it"
    → [create_content, grow]. Never includes "unknown".
    """
    lang = (language or "en").lower()
    if lang not in ("en", "ur", "ar"):
        lang = "en"
    lowered = text.lower()
    tokens = _tokens(text)

    scored: list[tuple[str, float]] = []
    for intent in INTENTS:
        if intent == UNKNOWN:
            continue
        hits = _score_intent(tokens, lowered, intent, lang)
        if intent == ANALYZE_CONTENT and _URL_RE.search(text):
            hits += 2
        conf = _confidence(hits)
        if conf >= threshold:
            scored.append((intent, conf))
    scored.sort(key=lambda p: p[1], reverse=True)
    return scored


def module_for(intent: str) -> dict:
    """Routing table entry for an intent (unknown → support)."""
    return MODULES.get(intent, MODULES[UNKNOWN])


def extract_urls(text: str) -> list[str]:
    return re.findall(r"https?://[^\s)>\]]+", text)
