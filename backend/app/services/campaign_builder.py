"""AI Campaign Builder — analyze → propose → estimate → draft.

Flow:
  1. analyze content (reuse the post/link analysis engine; for pasted text
     run the same extractors without network)
  2. derive content signals (topics/hashtags/categories/language/entities/
     analysis score) and cache them by content hash
  3. match content → audience segments (explainable)
  4. propose objective/topics/languages/segments/budget/duration via the AI
     provider (ads_ai, strict JSON) with a deterministic heuristic fallback
  5. estimated reach via an honest, documented formula (estimate — not a
     guarantee)
  6. persist as DRAFT. NOTHING launches without explicit advertiser approval
     (draft → pending_approval → approved via the API; ``active`` is not
     reachable through the public API in Phase 1).

Every agent step is logged to ad_decisions in the GrowthDecision audit style.
"""
from __future__ import annotations

import hashlib
import math
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ads import (
    AdCampaign, AdCampaignStatus, AdDecision, AdObjective, ContentSignal,
)
from app.models.core import User
from app.services import (
    ads_ai,
    audience_intelligence as ai_svc,
    audience_matching as match_svc,
    geo as geo_svc,
    plans as plans_svc,
)
from app.services.analysis.extract import (
    analyze_language_full, detect_language, extract_hashtags,
    extract_mentions, normalize_url,
)
from app.services.analysis.scoring import score_content
from app.services.analysis.service import analyze_post, analysis_summary
from app.services.language import recommend_languages

ESTIMATE_DISCLAIMER = (
    "Estimate — not a guarantee. Illustrative multipliers, not measured "
    "data. Real reach depends on content quality, delivery, budget, "
    "competition, and user attention. Never presented as a promise of "
    "views, followers, leads, or sales."
)

# Heuristic hashtag → taxonomy keyword index (honest keyword matching only).
_KEYWORD_INDEX: dict[str, str] = {}
for _slug, _en, _ur in ai_svc.TOPICS:
    _KEYWORD_INDEX[_slug.replace("_", "")] = _slug
    for _tok in _en.lower().replace("&", " ").split():
        if len(_tok) > 2:
            _KEYWORD_INDEX.setdefault(_tok, _slug)


def content_hash(content: str) -> str:
    return hashlib.sha256(content.strip().encode("utf-8")).hexdigest()


def hashtags_to_topics(hashtags: list[str]) -> list[str]:
    """Map content hashtags onto taxonomy slugs by keyword match (heuristic)."""
    topics: list[str] = []
    for tag in hashtags:
        slug = _KEYWORD_INDEX.get(tag.lower())
        if slug and slug not in topics:
            topics.append(slug)
    return topics[:8]


def categories_for(media_type: str) -> list[str]:
    return {"video": ["video"], "photo": ["photo"], "rich": ["rich"],
            "link": ["link"]}.get(media_type or "unknown", ["link"])


def signals_from_text(text: str) -> dict:
    """Content signals from pasted text (no network) using analysis extractors."""
    hashtags = extract_hashtags(text)
    mentions = extract_mentions(text)
    language = detect_language(text)
    lang_full = analyze_language_full(text)
    # All languages with real evidence: primary + mixed-content alternatives.
    languages = [lang_full["primary"]]
    if lang_full.get("is_mixed_language"):
        for alt in lang_full.get("alternatives", []):
            if alt["code"] not in languages:
                languages.append(alt["code"])
    score = score_content(
        title=text[:120], description=text, hashtag_count=len(hashtags),
        media_type="unknown", has_thumbnail=False, language=language)
    return {
        "topics": hashtags_to_topics(hashtags),
        "hashtags": hashtags,
        "categories": ["text"],
        "language": language,
        "languages": languages,
        "language_metadata": lang_full,
        "concepts": lang_full.get("concepts", []),
        "entities": mentions,
        "analysis_score": float(score.get("score", 0)),
        "analysis_detail": score,
        "fetch_level": "local",
        "title": text[:120],
    }


def signals_from_analysis(row) -> dict:
    """Content signals from a cached/full PostAnalysis row."""
    score = row.score or {}
    return {
        "topics": hashtags_to_topics(list(row.hashtags or [])),
        "hashtags": list(row.hashtags or []),
        "categories": categories_for(row.media_type),
        "language": row.language or "unknown",
        "entities": list(row.mentions or []) + ([row.author] if row.author else []),
        "analysis_score": float(score.get("score", 0)),
        "analysis_detail": score,
        "fetch_level": row.fetch_level,
        "title": row.title or "",
        "platform": row.platform,
    }


async def get_or_extract_signals(db: AsyncSession, *,
                                 url: str | None = None,
                                 content: str | None = None) -> tuple[dict, str]:
    """Return (signals dict, post_hash). URL analysis goes through the
    analysis engine (cached 7 days); pasted text uses local extractors.
    Never raises — degrades to minimal signals on failure."""
    if url:
        try:
            row = await analyze_post(normalize_url(url), db)
            sig = signals_from_analysis(row)
        except Exception:
            sig = signals_from_text(url)
        phash = content_hash("url:" + normalize_url(url))
    elif content:
        sig = signals_from_text(content)
        phash = content_hash("text:" + content)
    else:
        raise ValueError("Provide either url or content.")

    cached = (await db.execute(
        select(ContentSignal).where(ContentSignal.post_hash == phash)
    )).scalar_one_or_none()
    if cached is None:
        cached = ContentSignal(
            post_hash=phash, topics=sig["topics"], hashtags=sig["hashtags"],
            categories=sig["categories"], language=sig["language"],
            entities=sig["entities"], analysis_score=sig["analysis_score"])
        db.add(cached)
        await db.commit()
        await db.refresh(cached)
    return {
        "topics": list(cached.topics or []), "hashtags": list(cached.hashtags or []),
        "categories": list(cached.categories or []),
        "language": cached.language,
        "entities": list(cached.entities or []),
        "analysis_score": float(cached.analysis_score or 0),
        "fetch_level": sig.get("fetch_level", "cached"),
        "title": sig.get("title", ""),
        "post_hash": phash,
    }, phash


def heuristic_proposal(signals: dict, matches: list[dict],
                       budget_cap: float | None) -> dict:
    """Deterministic fallback proposal when the AI provider is unavailable."""
    text = " ".join(signals.get("hashtags") or []).lower()
    objective = "views"
    if any(k in text for k in ("shop", "buy", "sale", "order", "discount")):
        objective = "sales"
    elif any(k in text for k in ("follow",)):
        objective = "followers"
    elif any(k in text for k in ("dm", "signup", "register", "apply")):
        objective = "leads"
    budget = 50.0
    if budget_cap and budget_cap > 0:
        budget = min(budget, float(budget_cap))
    return {
        "objective": objective,
        "topics": list(signals.get("topics") or []),
        "languages": ([signals["language"]] if signals.get("language")
                      not in (None, "unknown") else ["en"]),
        "segment_ids": [m["segment_id"] for m in matches[:3]],
        "recommended_budget_usd": budget,
        "duration_days": 7,
        "rationale": ("Heuristic proposal (no AI provider configured): objective "
                      "from content cues, top matching segments, default 7-day "
                      "/ USD 50 budget suggestion."),
        "heuristic": True,
    }


_OBJECTIVE_MULTIPLIER = {
    "views": 1.0, "engagement": 0.6, "followers": 0.4,
    "leads": 0.25, "sales": 0.2,
}


def estimate_reach(segments: list, objective: str, budget: float,
                   duration_days: int,
                   geo: dict | None = None) -> dict:
    """Honest reach estimate. Documented formula (illustrative, not measured):

        base        = Σ size_estimate of the chosen segments
        duration_f  = 0.5 + 0.5 * min(duration_days / 7, 1)      (0.57..1.0)
        budget_f    = 1 + min(log10(1 + budget) / 2, 1)          (1.0..2.0)
        objective_f = {views 1.0, engagement 0.6, followers 0.4,
                       leads 0.25, sales 0.2}
        geo_f       = 1.0 for worldwide; otherwise the share of the chosen
                      segment base whose declared geography is global or
                      inside the selected countries. When NO chosen segment
                      carries geography data, an illustrative equal-share
                      assumption is used: len(countries) / 249, clearly
                      labeled as illustrative.
        reach_low   = base * 0.02 * duration_f * budget_f * objective_f * geo_f
        reach_high  = base * 0.15 * duration_f * budget_f * objective_f * geo_f

    ``geo`` = {"mode": "ai_recommended"|"worldwide"|"custom",
               "countries": [ISO codes]}. Worldwide (or empty) → geo_f = 1.0.
    """
    base = sum(int(getattr(s, "size_estimate", 0) or 0) for s in segments)
    duration_f = 0.5 + 0.5 * min(max(duration_days, 1) / 7.0, 1.0)
    budget_f = 1.0 + min(math.log10(1.0 + max(budget, 0.0)) / 2.0, 1.0)
    objective_f = _OBJECTIVE_MULTIPLIER.get(objective, 1.0)

    geo = geo or {}
    mode = str(geo.get("mode") or "worldwide").lower()
    countries = [str(c).upper() for c in (geo.get("countries") or [])]
    if mode == "worldwide" or not countries:
        geo_f = 1.0
        geo_note = "Worldwide delivery — full segment base counts."
    else:
        in_geo = sum(int(getattr(s, "size_estimate", 0) or 0)
                     for s in segments
                     if not getattr(s, "geography", "")
                     or str(getattr(s, "geography", "")).upper() in countries)
        has_geo_data = any(getattr(s, "geography", "") for s in segments)
        if base > 0 and has_geo_data:
            geo_f = in_geo / base
            geo_note = (f"{in_geo}/{base} of the chosen segment base is "
                        f"global or inside the selected countries.")
        else:
            # No geography data on the segments — illustrative fallback,
            # never presented as measured.
            geo_f = len(countries) / len(geo_svc.COUNTRIES)
            geo_note = (f"Illustrative: {len(countries)} of "
                        f"{len(geo_svc.COUNTRIES)} countries selected; equal "
                        f"share per country assumed (no segment geography "
                        f"data yet).")

    low = int(base * 0.02 * duration_f * budget_f * objective_f * geo_f)
    high = int(base * 0.15 * duration_f * budget_f * objective_f * geo_f)
    return {
        "estimated_reach_low": low,
        "estimated_reach_high": high,
        "formula": {
            "audience_base": base,
            "duration_factor": round(duration_f, 3),
            "budget_factor": round(budget_f, 3),
            "objective_factor": objective_f,
            "geography_factor": round(geo_f, 4),
            "geography_mode": mode,
            "geography_countries": countries,
            "geography_note": geo_note,
        },
        "disclaimer": ESTIMATE_DISCLAIMER,
    }


async def recompute_estimate(db: AsyncSession, campaign: AdCampaign) -> dict:
    """Recompute the reach estimate from the campaign's CURRENT settings.

    Used after PATCH edits (budget/duration/objective/segments/geography)
    so the displayed estimate never goes stale. Deterministic.
    """
    segments = await ai_svc.list_active_segments(db)
    chosen = [s for s in segments
              if str(s.id) in set(campaign.segment_ids or [])]
    est = estimate_reach(
        chosen, campaign.objective.value, float(campaign.budget or 0),
        int(campaign.duration_days or 7),
        geo={"mode": campaign.geo_mode,
             "countries": list(campaign.geo_countries or [])})
    est["plan"] = campaign.plan
    return est


async def _log(db: AsyncSession, campaign_id, agent: str, action: str,
               reasons: list[str], metrics: dict | None = None,
               geo: dict | None = None) -> None:
    db.add(AdDecision(
        campaign_id=campaign_id, agent=agent, action=action,
        details={"reasons": reasons, "metrics": metrics or {},
                 "geo": geo or {},
                 "disclaimer": ESTIMATE_DISCLAIMER}))


async def build_campaign(db: AsyncSession, user: User, *,
                         url: str | None = None, content: str | None = None,
                         budget_cap: float | None = None,
                         objective_hint: str | None = None,
                         geo_mode: str | None = None,
                         geo_countries: list[str] | None = None,
                         plan: str | None = None,
                         package_id: str | None = None) -> dict:
    """Run the full builder flow and persist a DRAFT campaign.

    plan: "free" | "paid" (default "paid").
      free = Free Grow: worldwide audience only, zero budget, no spend.
             Limited: at most plans.FREE_PLAN_MAX_ACTIVE_CAMPAIGNS live
             campaigns per advertiser; budget_cap / package_id / non-worldwide
             geo are rejected.
      paid = Paid Boost: no manual budgeting — pick a package_id (fixed
             price + duration) or pass budget_cap for a custom cap.
    """
    if not url and not content:
        raise ValueError("Provide either url or content.")
    plan = (plan or "paid").strip().lower()
    if plan not in ("free", "paid"):
        raise ValueError("plan must be 'free' or 'paid'.")
    package = plans_svc.get_package(package_id)
    if package_id and package is None:
        raise ValueError(
            f"Unknown package '{package_id}'. Choose from "
            f"{[p['id'] for p in plans_svc.PAID_PACKAGES]}.")
    if plan == "free":
        # Free Grow: no budget, worldwide only. Reject anything that
        # contradicts the free contract so the client learns it loudly.
        if budget_cap is not None and float(budget_cap) > 0:
            raise ValueError(
                "Free campaigns have no budget — choose Paid Boost for a "
                "budgeted campaign.")
        if package is not None:
            raise ValueError(
                "Free campaigns don't use packages — choose Paid Boost.")
        if geo_mode is not None and geo_mode.strip().lower() != "worldwide":
            raise ValueError(
                "Free campaigns are worldwide-only — choose Paid Boost for "
                "country targeting.")
        if geo_countries:
            raise ValueError(
                "Free campaigns are worldwide-only — choose Paid Boost for "
                "country targeting.")
        geo_mode = "worldwide"
        # Free quota: limited live campaigns per advertiser.
        live = (await db.execute(
            select(func.count()).select_from(AdCampaign).where(
                AdCampaign.owner_id == user.id,
                AdCampaign.plan == "free",
                AdCampaign.status.in_(
                    [AdCampaignStatus(s)
                     for s in plans_svc.FREE_PLAN_COUNTED_STATUSES])))).scalar()
        if int(live or 0) >= plans_svc.FREE_PLAN_MAX_ACTIVE_CAMPAIGNS:
            raise ValueError(
                f"Free Grow allows up to "
                f"{plans_svc.FREE_PLAN_MAX_ACTIVE_CAMPAIGNS} live campaigns "
                f"at a time — pause or complete one, or choose Paid Boost "
                f"for unlimited campaigns.")
    elif package is not None and budget_cap is not None \
            and float(budget_cap) > 0:
        raise ValueError("Use either package_id or budget_cap, not both.")
    if budget_cap is not None and budget_cap < 0:
        raise ValueError("budget_cap must be >= 0.")
    mode = geo_svc.validate_geo_mode(geo_mode)
    custom_countries: list[str] = []
    if mode == "custom":
        custom_countries = geo_svc.validate_countries(geo_countries)

    # 1) analyze → signals
    signals, phash = await get_or_extract_signals(db, url=url, content=content)

    # 2) match → ranked segments. Advertiser-chosen custom geography
    # filters here; worldwide filters nothing; ai_recommended must NOT be
    # pre-filtered — the AI suggestion is derived from these unfiltered
    # matches (post language + declared segment geography).
    segments = await ai_svc.list_active_segments(db)
    matches = await match_svc.match_segments(
        db, signals, segments,
        geo_countries=(custom_countries if mode == "custom" else None))

    # 3) propose (AI with heuristic fallback)
    catalog = [{"id": str(s.id), "name": s.name, "topics": list(s.topics or []),
                "languages": list(s.languages or []),
                "description": s.description} for s in segments]
    summary = (
        f"Title: {signals.get('title', '')[:200]}\n"
        f"Topics: {', '.join(signals['topics']) or '(none)'}\n"
        f"Hashtags: {', '.join(signals['hashtags'][:10]) or '(none)'}\n"
        f"Language: {signals['language']}\n"
        f"Analysis score: {signals['analysis_score']:.0f}/100")
    proposal = await ads_ai.propose_campaign_via_ai(
        summary, catalog, budget_cap=budget_cap)
    used_ai = proposal is not None
    if proposal is None:
        proposal = heuristic_proposal(signals, matches, budget_cap)
    if plan == "free":
        # Free Grow never carries a budget — the proposal's suggestion is
        # replaced, not just capped.
        proposal["recommended_budget_usd"] = 0.0
    elif package is not None:
        # Paid Boost: no manual budgeting — the package IS the budget.
        proposal["recommended_budget_usd"] = float(package["price_usd"])
        proposal["duration_days"] = int(package["duration_days"])
        proposal["package_id"] = package["id"]
        proposal["package_name"] = package["name"]
    if objective_hint in ("views", "engagement", "followers", "leads", "sales"):
        proposal["objective"] = objective_hint

    # 4) geography: AI suggests, advertiser decides. The suggestion is
    # deterministic (post language + declared segment geography) and every
    # country carries a reason. Worldwide/custom are the advertiser's
    # explicit choice.
    suggestion = geo_svc.suggest_geography(signals, matches)
    if mode == "worldwide":
        effective_countries: list[str] = []
    elif mode == "custom":
        effective_countries = custom_countries
    else:  # ai_recommended
        effective_countries = list(suggestion["countries"])
        if not effective_countries:
            # No confident signal — worldwide is the honest default.
            mode = "worldwide"

    # 5) estimate (geography-aware; free campaigns estimate worldwide
    # organic reach with budget factor 1.0 — still labeled estimate)
    chosen = [s for s in segments
              if str(s.id) in set(proposal.get("segment_ids") or [])]
    estimate = estimate_reach(
        chosen, proposal["objective"],
        float(proposal.get("recommended_budget_usd", 0)),
        int(proposal.get("duration_days", 7)),
        geo={"mode": mode, "countries": effective_countries})
    estimate["plan"] = plan

    # 6) persist draft
    meta = ads_ai.ai_source_meta()
    # Multilingual targeting: advertiser picks one, several, or all
    # relevant languages; AI suggests additional ones with reasons.
    content_langs = list(signals.get("languages") or
                         [signals.get("language", "unknown")])
    seg_dicts = [{"name": s.name, "topics": list(s.topics or []),
                  "language_coverage": list(
                      (getattr(s, "language_coverage", None) or [])
                      + (s.languages or []))}
                 for s in segments]
    suggested_langs = recommend_languages(
        content_langs, signals.get("concepts"), seg_dicts)
    campaign = AdCampaign(
        owner_id=user.id,
        plan=plan,
        package_id=(package["id"] if package is not None else None),
        objective=AdObjective(proposal["objective"]),
        content_ref=(url or (content or ""))[:2000],
        content_signals={k: v for k, v in signals.items()
                         if k != "analysis_detail"},
        topics=list(proposal.get("topics") or []),
        languages=list(proposal.get("languages") or []),
        language_targeting_mode=("multiple" if len(content_langs) > 1
                                 else "single"),
        target_languages=content_langs,
        suggested_languages=[{"code": s["code"], "reason": s["reason"]}
                             for s in suggested_langs],
        segment_ids=list(proposal.get("segment_ids") or []),
        budget=float(proposal.get("recommended_budget_usd", 0)),
        duration_days=int(proposal.get("duration_days", 7)),
        geo_mode=mode,
        geo_countries=effective_countries,
        suggested_geography=suggestion,
        status=AdCampaignStatus.draft,
        estimate=estimate,
        ai_provider=meta["ai_provider"], ai_model=meta["ai_model"],
        dev=meta["dev"])
    db.add(campaign)
    await db.flush()

    # 6) audit trail
    await _log(db, campaign.id, "content", "analyze",
               [f"Content analyzed ({signals.get('fetch_level')}).",
                f"Topics: {', '.join(signals['topics']) or '(none)'}; "
                f"language: {signals['language']}."],
               {"analysis_score": signals["analysis_score"],
                "post_hash": phash},
               geo=geo_svc.geo_context(campaign))
    await _log(db, campaign.id, "matching", "rank_segments",
               [f"{m['name']}: score {m['score']}"
                for m in matches[:5]] or ["No segment met the threshold."],
               {"matches": len(matches),
                "threshold": match_svc.DEFAULT_THRESHOLD},
               geo=geo_svc.geo_context(campaign))
    await _log(db, campaign.id, "builder", "propose",
               [("AI proposal" if used_ai else "Heuristic proposal") + ": "
                + (proposal.get("rationale") or "")],
               {"objective": proposal["objective"],
                "budget_usd": proposal.get("recommended_budget_usd"),
                "duration_days": proposal.get("duration_days"),
                "ai_provider": meta["ai_provider"], "dev": meta["dev"],
                "estimated_reach": [estimate["estimated_reach_low"],
                                    estimate["estimated_reach_high"]]},
               geo=geo_svc.geo_context(campaign))
    geo_label = {
        "ai_recommended": "AI-recommended countries",
        "worldwide": "worldwide", "custom": "advertiser-chosen countries"}.get(
            mode, mode)
    await _log(db, campaign.id, "builder", "geography_targeting",
               [f"Geography mode: {geo_label}."] +
               ([f"Countries: {', '.join(effective_countries)}."]
                if effective_countries else []) +
               suggestion.get("reasons", [])[:6],
               {"geo_mode": mode, "geo_countries": effective_countries,
                "geography_factor": estimate["formula"]["geography_factor"]},
               geo=geo_svc.geo_context(campaign))
    await db.commit()
    await db.refresh(campaign)
    return {
        "campaign": campaign, "signals": signals, "matches": matches,
        "proposal": proposal, "estimate": estimate, "used_ai": used_ai,
    }
