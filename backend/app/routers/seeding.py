"""Smart Community Seeding — free organic growth strategy #3.

Suggests public communities (Reddit-style subreddits, Facebook groups) whose
*declared* topics match the creator's content, and generates a value-first,
rules-aware draft post for each match.

Hard rules (never negotiable):
- No scraping. Communities come from a curated STATIC mapping below; Virello
  never crawls Reddit, Facebook, or any third party.
- No auto-posting, no bots. The user copies the draft and posts it manually
  in their own account. The flow below only tracks status:
  suggested -> approved -> posted.
- Drafts are honestly labeled: ``draft_source`` is ``"ai"`` (with provider
  metadata) or ``"heuristic"``. No fake engagement, no spammy CTAs.
"""
from __future__ import annotations

import json
import re
import uuid
from datetime import datetime
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import JSON, DateTime, ForeignKey, String, Text, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, get_db
from app.core.deps import get_current_user
from app.models.core import GUID, User
from app.services.ai.base import (
    AIProviderError,
    AIProviderNotConfigured,
    AIRequest,
    get_ai_provider,
)
from app.services.discovery.topics_seed import TOPICS

router = APIRouter()

# ------------------------------------------------------------------ model
# (Lives here, next to its only consumer, so seeding stays self-contained.)


def _hex() -> str:
    return uuid.uuid4().hex


class SeedingPlan(Base):
    """One community suggestion + draft, tracked through the manual flow.

    suggested -> approved -> posted. The user posts manually; Virello never
    touches the third-party platform.
    """

    __tablename__ = "seeding_plans"
    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_hex)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    community_name: Mapped[str] = mapped_column(String(255))
    platform: Mapped[str] = mapped_column(String(16))  # reddit | facebook
    topics: Mapped[list] = mapped_column(JSON, default=list)
    content: Mapped[str] = mapped_column(Text)
    draft: Mapped[str] = mapped_column(Text)
    # "ai" (provider answered) | "heuristic" (deterministic template)
    draft_source: Mapped[str] = mapped_column(String(16), default="heuristic")
    draft_meta: Mapped[dict | None] = mapped_column(JSON, nullable=True,
                                                   default=None)
    # suggested | approved | posted
    status: Mapped[str] = mapped_column(String(16), default="suggested",
                                        index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now())


# ------------------------------------------------- static community map
# Curated by hand. Entries are public-community facts (name, platform,
# declared topics, community norms). Nothing is scraped or fetched live.
COMMUNITIES: list[dict[str, Any]] = [
    {"name": "r/fitness", "platform": "reddit",
     "topics": ["fitness", "health"],
     "rules_note": "Read the community wiki first; experience and question "
                   "posts do best. No direct self-promotion.",
     "member_hint": "Large fitness community — beginners to athletes"},
    {"name": "r/gaming", "platform": "reddit",
     "topics": ["gaming"],
     "rules_note": "Gaming content only; keep self-promotion under the "
                   "community's allowed ratio (usually ~10%).",
     "member_hint": "One of the largest gaming communities online"},
    {"name": "r/Entrepreneur", "platform": "reddit",
     "topics": ["business", "marketing", "finance"],
     "rules_note": "Value-first discussion; no sales pitches, surveys, or "
                   "link-dumps without moderator approval.",
     "member_hint": "Founders and small-business owners"},
    {"name": "r/technology", "platform": "reddit",
     "topics": ["technology"],
     "rules_note": "Substantive articles and discussion only; no personal "
                   "blogs, reposts, or low-effort links.",
     "member_hint": "Tech news readers and professionals"},
    {"name": "r/food", "platform": "reddit",
     "topics": ["food"],
     "rules_note": "Original food photos; put the recipe in the comments; "
                   "no blog-spam or link-dumps.",
     "member_hint": "Home cooks and food lovers"},
    {"name": "r/travel", "platform": "reddit",
     "topics": ["travel"],
     "rules_note": "Trip reports and itineraries welcome; no referral or "
                   "affiliate links.",
     "member_hint": "Travelers planning and sharing trips"},
    {"name": "r/malefashionadvice", "platform": "reddit",
     "topics": ["fashion", "lifestyle"],
     "rules_note": "Feedback culture — ask, don't advertise; no buy/sell/"
                   "trade posts.",
     "member_hint": "Style enthusiasts giving honest feedback"},
    {"name": "r/learnpython", "platform": "reddit",
     "topics": ["technology", "education"],
     "rules_note": "Show your code and what you tried; beginner questions "
                   "are welcome — read the posting guidelines first.",
     "member_hint": "Programming learners and mentors"},
    {"name": "r/personalfinance", "platform": "reddit",
     "topics": ["finance", "business"],
     "rules_note": "No ads, referral links, or self-promotion; read the "
                   "wiki before asking basic questions.",
     "member_hint": "Personal-finance readers and savers"},
    {"name": "r/GetMotivated", "platform": "reddit",
     "topics": ["motivation", "health", "fitness"],
     "rules_note": "Motivational content only; no product promotion or "
                   "spam.",
     "member_hint": "People looking for daily motivation"},
    {"name": "Startup Founders & Entrepreneurs", "platform": "facebook",
     "topics": ["business", "marketing"],
     "rules_note": "Introduce yourself first; value posts outperform links — "
                   "ask admins before sharing any offer.",
     "member_hint": "Founders networking and sharing lessons"},
    {"name": "Healthy Recipes & Meal Prep", "platform": "facebook",
     "topics": ["food", "health", "fitness"],
     "rules_note": "Share the full recipe inside the post; no external-link "
                   "dumps.",
     "member_hint": "Home cooks swapping healthy recipes"},
    {"name": "Travel Buddies & Tips", "platform": "facebook",
     "topics": ["travel"],
     "rules_note": "Real trip photos and practical tips welcome; no agency "
                   "spam.",
     "member_hint": "Travelers exchanging tips and itineraries"},
    {"name": "Online Learning & Courses", "platform": "facebook",
     "topics": ["education"],
     "rules_note": "Share what you learned; no course-selling without "
                   "admin permission.",
     "member_hint": "Self-learners and course takers"},
    {"name": "r/photography", "platform": "reddit",
     "topics": ["photography", "art"],
     "rules_note": "Original photos only; include camera/settings context; "
                   "no watermark spam or for-sale posts.",
     "member_hint": "Photographers from hobbyists to pros"},
    {"name": "r/Frugal", "platform": "reddit",
     "topics": ["finance", "lifestyle"],
     "rules_note": "Practical frugality tips; no referral links or "
                   "self-promotion.",
     "member_hint": "Budget-conscious savers"},
]

# ------------------------------------------------- topic matching
# Uses the discovery taxonomy slugs; extra keyword aliases so free-text
# content ("my new game", "home workout") maps to the right topic.
_TOPIC_EN = {slug: en for slug, en, _ur in TOPICS}
_ALIASES: dict[str, set[str]] = {
    "technology": {"tech", "ai", "software", "app", "gadget", "computer",
                   "programming", "coding", "developer"},
    "business": {"startup", "entrepreneur", "company", "founder"},
    "fitness": {"gym", "workout", "exercise", "training"},
    "food": {"recipe", "cooking", "meal", "kitchen", "baking"},
    "travel": {"trip", "vacation", "flight", "hotel", "itinerary"},
    "fashion": {"style", "outfit", "clothing", "dress"},
    "education": {"learn", "course", "study", "school", "student", "tutorial"},
    "gaming": {"game", "gamer", "esports", "playstation", "xbox"},
    "health": {"wellness", "mental", "sleep", "diet"},
    "finance": {"money", "invest", "crypto", "stock", "budget", "saving"},
    "marketing": {"ads", "seo", "brand", "social media", "advertising"},
    "motivation": {"inspiration", "inspire", "mindset", "discipline"},
    "sports": {"football", "cricket", "soccer", "match"},
    "music": {"song", "playlist", "band", "concert"},
    "photography": {"photo", "camera", "portrait", "lens"},
    "art": {"design", "painting", "illustration", "drawing"},
    "beauty": {"skincare", "makeup", "cosmetics"},
    "pets": {"dog", "cat", "puppy"},
    "news": {"headline", "breaking"},
    "comedy": {"funny", "meme", "humor", "joke"},
    "parenting": {"kids", "baby", "mom", "dad"},
    "realestate": {"property", "house", "rent"},
    "automobiles": {"car", "bike", "vehicle"},
    "lifestyle": {"daily", "routine", "habit"},
}

_WORD = re.compile(r"[a-z0-9]+(?: [a-z0-9]+)?")


def _topic_keywords(slug: str) -> set[str]:
    kws = {slug}
    kws.update(w for w in _WORD.findall(_TOPIC_EN.get(slug, "").lower()))
    kws.update(_ALIASES.get(slug, set()))
    return {k for k in kws if len(k) >= 3}


def _normalize_topic(raw: str) -> str | None:
    """Map a user-supplied topic string to a taxonomy slug, or None."""
    t = raw.strip().lower()
    if not t:
        return None
    for slug, en, _ur in TOPICS:
        if t == slug or t == en.lower():
            return slug
    for slug in _TOPIC_EN:
        if t in _ALIASES.get(slug, set()):
            return slug
    return None


def match_communities(content: str, topics: list[str]) -> list[dict]:
    """Return matched community dicts (with matched_topics), best first."""
    matched_slugs: set[str] = set()
    for raw in topics or []:
        slug = _normalize_topic(raw)
        if slug:
            matched_slugs.add(slug)

    hay = f" {content.lower()} "
    for slug in _TOPIC_EN:
        for kw in _topic_keywords(slug):
            if f" {kw} " in hay or f" {kw}," in hay or f" {kw}." in hay:
                matched_slugs.add(slug)
                break

    scored: list[tuple[int, dict[str, Any], list[str]]] = []
    for c in COMMUNITIES:
        hit = [t for t in c["topics"] if t in matched_slugs]
        if hit:
            scored.append((len(hit), c, hit))
    scored.sort(key=lambda s: (-s[0], s[1]["name"]))
    return [{"community": c, "matched_topics": hit} for _, c, hit in scored]


# ------------------------------------------------- draft generation
# Banned from every draft: spammy CTAs and guarantee language.
_BANNED_CTA = (
    "buy now", "click here", "link in bio", "dm me", "limited offer",
    "act now", "guaranteed", "100% free money", "double your",
)

_SYSTEM_SEEDING = (
    "You are Virello's Community Seeding assistant. You write a value-first "
    "draft post for a PUBLIC online community (subreddit or Facebook group) "
    "based on a creator's content. The draft must:\n"
    "1. Lead with genuine value or a real question for the community — never "
    "a sales pitch.\n"
    "2. Respect the community's stated rules (given in the prompt).\n"
    "3. Contain NO call-to-action like 'buy now', 'click here', 'link in "
    "bio', 'DM me'. A soft 'happy to share more if useful' is the most you "
    "may do.\n"
    "4. Never promise virality, reach, or results.\n"
    "Respond with ONLY a JSON object: {\"draft\": \"...\"}. No markdown, no "
    "commentary."
)


def _strip_fences(text: str) -> str:
    t = text.strip()
    if t.startswith("```"):
        t = re.sub(r"^```[a-zA-Z]*\n?", "", t)
        t = re.sub(r"\n?```$", "", t)
    return t.strip()


def _looks_spammy(text: str) -> bool:
    low = text.lower()
    return any(phrase in low for phrase in _BANNED_CTA)


def _snippet(content: str, rules_note: str, limit: int = 220) -> str:
    """Content excerpt, minus URLs when the community disallows link-dumps."""
    text = content.strip()
    if re.search(r"no .*link", rules_note.lower()):
        text = re.sub(r"https?://\S+", "[link removed — community rules]",
                      text)
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def _heuristic_draft(content: str, community: dict[str, Any],
                     matched_topics: list[str]) -> str:
    topics_txt = ", ".join(matched_topics) if matched_topics else "this topic"
    return (
        f"Wanted to share something with the {community['name']} community "
        f"about {topics_txt} — and hopefully learn from you all too.\n\n"
        f"{_snippet(content, community['rules_note'])}\n\n"
        "The part I'm most curious about: what's worked for you here? "
        "Always looking to learn from people who actually do this every day."
    )


async def _draft_via_ai(content: str, community: dict[str, Any],
                        matched_topics: list[str]) -> tuple[str | None, dict]:
    """Try the configured AI provider; (None, {}) on ANY failure."""
    try:
        p = get_ai_provider()
        user = (
            f"Community: {community['name']} ({community['platform']})\n"
            f"Community rules to respect: {community['rules_note']}\n"
            f"Relevant topics: {', '.join(matched_topics) or 'general'}\n"
            f"Creator's content:\n{content[:1200]}"
        )
        resp = await p.complete(AIRequest(
            agent="seeding_draft", system=_SYSTEM_SEEDING, user=user,
            max_tokens=700, temperature=0.5, json_mode=True,
            metadata={"seeding": True}))
        payload = json.loads(_strip_fences(resp.text or ""))
        draft = payload.get("draft") if isinstance(payload, dict) else None
        if (isinstance(draft, str) and len(draft.strip()) >= 40
                and not _looks_spammy(draft)):
            return draft.strip(), {
                "ai_provider": getattr(p, "name", "unknown"),
                "ai_model": getattr(p, "model", "") or "",
                "dev": getattr(p, "name", "") == "dev",
            }
    except (AIProviderNotConfigured, AIProviderError, ValueError,
            AttributeError, TypeError, KeyError):
        pass
    return None, {}


async def make_draft(content: str, community: dict[str, Any],
                     matched_topics: list[str]) -> tuple[str, str, dict]:
    """(draft, source, meta) — AI first, deterministic template fallback."""
    draft, meta = await _draft_via_ai(content, community, matched_topics)
    if draft:
        return draft, "ai", meta
    return _heuristic_draft(content, community, matched_topics), "heuristic", {}


# ------------------------------------------------------------------ API
class SuggestIn(BaseModel):
    content: str
    topics: list[str] = []


class PlanPatchIn(BaseModel):
    status: Literal["suggested", "approved", "posted"]


_ALLOWED: dict[str, set[str]] = {
    "suggested": {"approved"},
    "approved": {"posted"},
    "posted": set(),
}


def _plan_out(p: SeedingPlan) -> dict[str, Any]:
    return {
        "id": p.id,
        "community_name": p.community_name,
        "platform": p.platform,
        "topics": p.topics,
        "content": p.content,
        "draft": p.draft,
        "draft_source": p.draft_source,
        "draft_meta": p.draft_meta or {},
        "status": p.status,
        "created_at": p.created_at.isoformat() if p.created_at else None,
        "updated_at": p.updated_at.isoformat() if p.updated_at else None,
    }


@router.post("/suggest")
async def suggest(body: SuggestIn, db: AsyncSession = Depends(get_db),
                  user: User = Depends(get_current_user)) -> dict:
    content = (body.content or "").strip()
    if not content:
        raise HTTPException(400, "content is required")
    matches = match_communities(content, body.topics or [])
    plans: list[dict[str, Any]] = []
    for m in matches:
        community = m["community"]
        draft, source, meta = await make_draft(content, community,
                                              m["matched_topics"])
        plan = SeedingPlan(
            user_id=user.id,
            community_name=community["name"],
            platform=community["platform"],
            topics=m["matched_topics"],
            content=content,
            draft=draft,
            draft_source=source,
            draft_meta=meta,
            status="suggested",
        )
        db.add(plan)
        await db.flush()
        out = _plan_out(plan)
        out["rules_note"] = community["rules_note"]
        out["member_hint"] = community["member_hint"]
        plans.append(out)
    await db.commit()
    return {
        "plans": plans,
        "matched": len(plans),
        "message": (f"{len(plans)} communities matched."
                    if plans else
                    "No communities matched these topics. Try topics like "
                    "gaming, fitness, business, tech, food, travel, fashion "
                    "or education."),
        "manual_note": "You post manually in your own account — Virello "
                       "never auto-posts.",
    }


@router.get("/plans")
async def list_plans(db: AsyncSession = Depends(get_db),
                     user: User = Depends(get_current_user)) -> dict:
    rows = (await db.execute(
        select(SeedingPlan).where(SeedingPlan.user_id == user.id)
        .order_by(SeedingPlan.created_at.desc()))).scalars().all()
    return {"plans": [_plan_out(p) for p in rows]}


@router.patch("/plans/{plan_id}")
async def update_plan(plan_id: str, body: PlanPatchIn,
                       db: AsyncSession = Depends(get_db),
                       user: User = Depends(get_current_user)) -> dict:
    plan = (await db.execute(
        select(SeedingPlan).where(SeedingPlan.id == plan_id,
                                 SeedingPlan.user_id == user.id))
            ).scalar_one_or_none()
    if plan is None:
        raise HTTPException(404, "Plan not found")
    if body.status != plan.status:
        if body.status not in _ALLOWED.get(plan.status, set()):
            raise HTTPException(
                422, f"Invalid transition {plan.status} -> {body.status}. "
                     "Allowed flow: suggested -> approved -> posted.")
        plan.status = body.status
    await db.commit()
    await db.refresh(plan)
    return {"plan": _plan_out(plan)}
