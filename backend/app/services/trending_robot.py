"""Trending Topics robot: discovers fresh trends, judges relevance for
Virello's audience, and writes ORIGINAL content for each topic.

Pipeline (see ``app/services/trending_orchestrator.py``):
    analyze_trends()        -> candidate topics with relevance scores
    generate_topic_content() -> original summary + AI insight per topic

Content contract (standing rule):
- Summaries are ORIGINAL — written fresh, never copied from Wikipedia,
  Google Trends, or any other source. The AI prompt enforces this, and
  the non-AI fallback builds summaries from templates by construction.
- Every topic carries an ai_insight: one actionable content-creation tip.

Trend sources (all free, no API keys):
- Google Trends daily-searches RSS (US): trending queries right now.
- Wikimedia pageviews API: most-viewed Wikipedia articles today.

Schedule: every 6 hours (see orchestrator module docstring).
"""
from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field
from datetime import date, timedelta, timezone

import httpx

log = logging.getLogger("virello.trending.robot")

HTTP_TIMEOUT = 25.0

# ------------------------------------------------------------------ sources

GTRENDS_RSS = "https://trends.google.com/trends/trendingsearches/daily/rss"
WIKI_TOP_URL = (
    "https://wikimedia.org/api/rest_v1/metrics/pageviews/top"
    "/en.wikipedia/all-access/{yyyy}/{mm:02d}/{dd:02d}"
)

# ------------------------------------------------------------------ model


@dataclass
class TrendCandidate:
    """A raw trend judged relevant for Virello's audience."""

    title: str
    score: int                      # 0-100 relevance/confidence score
    source: str                     # e.g. "google-trends", "wikipedia-pageviews"
    category: str = "general"       # best-guess category (see CATEGORY_KEYWORDS)
    keywords: list[str] = field(default_factory=list)


# ------------------------------------------------- relevance judging map
# Virello's audience: creators growing on social media, AI tools users,
# e-commerce/affiliate sellers. Topics matching these areas score high.

CATEGORY_KEYWORDS: dict[str, tuple[str, ...]] = {
    "social media": (
        "tiktok", "instagram", "youtube", "reel", "shorts", "viral", "influencer",
        "follower", "hashtag", "social media", "snapchat", "twitter", "thread",
        "livestream", "twitch", "creator",
    ),
    "content creation": (
        "video edit", "thumbnail", "hook", "caption", "script", "podcast",
        "vlog", "blog", "content", "camera", "filming", "editing", "capcut",
        "premiere", "photography",
    ),
    "ai tools": (
        "ai", "chatgpt", "artificial intelligence", "midjourney", "generative",
        "llm", "copilot", "gemini", "Muse", "openai", "stable diffusion",
        "machine learning", "prompt",
    ),
    "e-commerce": (
        "amazon", "shopify", "dropship", "ecommerce", "e-commerce", "affiliate",
        "online shopping", "product launch", "marketplace", "etsy", "selling",
    ),
    "marketing": (
        "marketing", "seo", "advertis", "brand", "growth", "email market",
        "funnel", "conversion", "campaign",
    ),
    "technology": (
        "app", "software", "smartphone", "gadget", "tech", "startup",
        "iphone", "android", "laptop",
    ),
    "finance": (
        "invest", "crypto", "bitcoin", "stock", "passive income", "budget",
        "money", "trading", "finance",
    ),
    "fitness": (
        "workout", "fitness", "gym", "exercise", "weight loss", "muscle",
        "yoga", "running", "health",
    ),
    "food": (
        "recipe", "cooking", "food", "restaurant", "meal", "baking", "diet",
    ),
    "fashion": (
        "fashion", "style", "outfit", "clothing", "sneaker", "beauty",
        "skincare", "makeup",
    ),
    "entertainment": (
        "movie", "netflix", "series", "music", "concert", "game", "gaming",
        "anime", "celebrity",
    ),
}

# Virello-core categories get a relevance boost: these are what the
# audience actually uses Virello for.
CORE_CATEGORIES = {"social media", "content creation", "ai tools", "e-commerce", "marketing"}

# Wikipedia navigation/meta pages that are never real topics.
WIKI_SKIP = {
    "main page", "special:search", "special:recentchanges",
    "wikipedia:featured", "portal:current events",
}


def _judge(title: str) -> tuple[str, int, list[str]]:
    """Return (category, score 0-100, matched keywords) for a raw trend title.

    Heuristic judge: keyword hits against CATEGORY_KEYWORDS. Core
    categories (social media / content creation / AI / e-commerce /
    marketing) score higher because they match Virello's audience.
    """
    lowered = title.lower()
    best_cat, best_hits = "general", []
    for cat, keywords in CATEGORY_KEYWORDS.items():
        hits = [kw for kw in keywords if kw in lowered]
        if len(hits) > len(best_hits):
            best_cat, best_hits = cat, hits
    if not best_hits:
        return "general", 20, []
    score = 40 + 12 * len(best_hits)
    if best_cat in CORE_CATEGORIES:
        score += 15
    return best_cat, min(score, 98), best_hits


# ------------------------------------------------------------------ fetch


async def _fetch_google_trends(client: httpx.AsyncClient, geo: str = "US") -> list[str]:
    """Daily trending searches from Google Trends RSS. Returns raw titles."""
    try:
        r = await client.get(GTRENDS_RSS, params={"geo": geo})
        r.raise_for_status()
    except Exception as exc:
        log.warning("google trends rss failed (%s): %s", geo, exc)
        return []
    titles = re.findall(r"<title>(.*?)</title>", r.text, re.DOTALL)
    # First <title> is the feed title itself; strip CDATA + HTML entities.
    out = []
    for t in titles[1:]:
        t = re.sub(r"<!\[CDATA\[|\]\]>", "", t).strip()
        t = t.replace("&amp;", "&").replace("&#39;", "'").replace("&quot;", '"')
        if t:
            out.append(t)
    return out


async def _fetch_wikipedia_top(client: httpx.AsyncClient) -> list[str]:
    """Most-viewed en.wikipedia articles yesterday. Returns article titles."""
    yesterday = date.today() - timedelta(days=1)
    url = WIKI_TOP_URL.format(yyyy=yesterday.year, mm=yesterday.month, dd=yesterday.day)
    try:
        r = await client.get(url, headers={"User-Agent": "VirelloTrendingBot/1.0"})
        r.raise_for_status()
        payload = r.json()
    except Exception as exc:
        log.warning("wikipedia pageviews failed: %s", exc)
        return []
    try:
        articles = payload["items"][0]["articles"]
    except (KeyError, IndexError, TypeError):
        return []
    out = []
    for a in articles[:60]:
        title = str(a.get("article", "")).replace("_", " ")
        if title.lower() in WIKI_SKIP or ":" in title:
            continue
        out.append(title)
    return out


# ------------------------------------------------------------------ analyze


async def analyze_trends(min_score: int = 45, max_candidates: int = 12) -> list[TrendCandidate]:
    """Fetch trend signals, judge relevance, return top candidates.

    - Pulls Google Trends (US) daily searches + Wikipedia most-viewed.
    - Judges each with _judge(); keeps score >= min_score.
    - Dedupes case-insensitively, best score wins.
    - Sorted by score desc, capped at max_candidates.
    """
    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT, follow_redirects=True) as client:
        raw: list[tuple[str, str]] = []  # (title, source)
        raw += [(t, "google-trends") for t in await _fetch_google_trends(client)]
        raw += [(t, "wikipedia-pageviews") for t in await _fetch_wikipedia_top(client)]

    seen: dict[str, TrendCandidate] = {}
    for title, source in raw:
        title = " ".join(title.split())
        if len(title) < 3 or len(title) > 120:
            continue
        category, score, hits = _judge(title)
        if score < min_score:
            continue
        key = title.lower()
        if key not in seen or score > seen[key].score:
            seen[key] = TrendCandidate(
                title=title, score=score, source=source,
                category=category, keywords=hits,
            )

    cands = sorted(seen.values(), key=lambda c: c.score, reverse=True)
    log.info("analyze_trends: %d raw signals -> %d candidates", len(raw), len(cands))
    return cands[:max_candidates]


# ------------------------------------------------------------------ content


_SYSTEM_PROMPT = (
    "You write ORIGINAL trending-topic cards for a social media growth app. "
    "Rules: (1) Never copy wording from any source — write every sentence fresh. "
    "(2) Summary: 2-3 lines explaining what the trend is and why it matters for "
    "content creators, in plain English. (3) AI insight: ONE line — a concrete, "
    "actionable content idea about this trend (format, hook, or angle). "
    "(4) No hype, no fake statistics, no claims you cannot verify. "
    "Return JSON: {\"summary\": ..., \"ai_insight\": ...}."
)


async def generate_topic_content(candidate: TrendCandidate) -> dict:
    """Write ORIGINAL summary + AI insight for a candidate topic.

    Uses the configured AI provider (Groq w/ fallback). If AI is
    unavailable, falls back to template-built original copy.
    Returns {"summary", "ai_insight", "category", "trend_score"}.
    """
    summary, insight = "", ""
    try:
        from app.services.ai.base import AIRequest, get_ai_provider

        provider = get_ai_provider()
        req = AIRequest(
            agent="trending_robot",
            system=_SYSTEM_PROMPT,
            user=f"Trend topic: {candidate.title}\nCategory hint: {candidate.category}",
            max_tokens=400,
            temperature=0.5,
            json_mode=True,
        )
        resp = await provider.complete(req)
        try:
            payload = json.loads(resp.text)
            summary = str(payload.get("summary", "")).strip()
            insight = str(payload.get("ai_insight", "")).strip()
        except (json.JSONDecodeError, AttributeError):
            log.warning("trending robot: AI returned non-JSON for %r", candidate.title)
    except Exception as exc:
        log.warning("trending robot: AI content failed for %r: %s", candidate.title, exc)

    if not summary or not insight:
        summary, insight = _template_content(candidate)

    return {
        "summary": summary,
        "ai_insight": insight,
        "category": candidate.category,
        "trend_score": candidate.score,
    }


def _template_content(candidate: TrendCandidate) -> tuple[str, str]:
    """Deterministic original fallback — no AI, no copied text."""
    t = candidate.title
    cat = candidate.category
    summary = (
        f"{t} is picking up attention right now. Creators in the {cat} space "
        f"are already posting about it, and early videos on the topic tend to "
        f"get a discovery boost while the trend is fresh."
    )
    insight = (
        f"Be early: post your take on {t} within 48 hours — explain it simply "
        f"for beginners and end with one opinion."
    )
    return summary, insight
