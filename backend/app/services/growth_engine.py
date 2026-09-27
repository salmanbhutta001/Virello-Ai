"""AI Growth Engine — autonomous analyze → audience match → distribute →
measure → learn → optimize loop.

Five coordinated agents (each writes explainable, auditable GrowthDecision rows):
  audience      — identifies suitable audience segments from post content,
                  topics, language, hashtags, creator profile, markets
  content       — proposes content variations (hooks/captions/hashtags/
                  thumbnail briefs/posting windows); creator's original stays
                  the baseline; AI variants apply only with creator opt-in
  distribution  — allocates discovery distribution across segments/variants
                  via feed ranking weights; starts initial distribution
  performance   — measures genuine interactions only (views/saves/visits/
                  dismissals); never fabricates engagement; watches fraud flags
  learning      — reallocates weight toward better-performing segments/
                  variants, pauses poor ones, requests fresh variants on
                  stagnation; pauses the loop on safety signals

Growth is genuine users + legitimate discovery + personalization only.
No fake views/likes, no bots, no spam, no artificial engagement — ever.
All scores are heuristic estimates; no virality or outcome is guaranteed.
"""
from __future__ import annotations

import asyncio
import hashlib
import math
import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.celery_app import celery
from app.core.config import settings
from app.core.database import get_db
from app.models.core import AuditLog, Campaign, CampaignStatus, FraudFlag, User
from app.models.growth import (
    DiscoveryInteraction,
    DiscoveryPlacement,
    PostAnalysis,
)
from app.models.growth_engine import (
    GrowthDecision,
    GrowthLoop,
    GrowthObservation,
    GrowthRound,
    GrowthSegment,
    GrowthVariant,
)
from app.services.discovery import get_my_interests
from app.services.growth_ai import (
    ai_source_meta,
    audience_segments_via_ai,
    content_variants_via_ai,
)

DISCLAIMER = (
    "Heuristic estimates and suggestions only — Virello never guarantees "
    "virality, reach, followers, leads, or sales."
)

DEFAULT_CONFIG = {
    "round_hours": 6,
    "explore_floor": 0.15,   # share of distribution always kept exploring
    "min_views": 20,         # min views before a segment may be paused
    "max_variants": 4,       # incl. the creator's original
    "auto_apply_variants": True,  # creator opt-in at loop start
    "dismiss_pause_rate": 0.6,
    "temperature": 0.7,      # softmax temperature for reallocation
}

AGENTS = ("audience", "content", "distribution", "performance", "learning", "system")


# ------------------------------------------------------------------ helpers
async def _decision(db: AsyncSession, loop_id: uuid.UUID, round_n: int,
                    agent: str, action: str, details: dict) -> None:
    details = {**details, "disclaimer": DISCLAIMER}
    db.add(GrowthDecision(loop_id=loop_id, round=round_n, agent=agent,
                          action=action, details=details))


async def _audit(db: AsyncSession, user_id: uuid.UUID, action: str,
                 details: str) -> None:
    db.add(AuditLog(user_id=user_id, action=action, details=details))


async def get_loop(db: AsyncSession, loop_id: uuid.UUID) -> GrowthLoop | None:
    return (await db.execute(
        select(GrowthLoop).where(GrowthLoop.id == loop_id))).scalar_one_or_none()


async def get_loop_for_campaign(db: AsyncSession,
                               campaign_id: uuid.UUID) -> GrowthLoop | None:
    return (await db.execute(select(GrowthLoop).where(
        GrowthLoop.campaign_id == campaign_id))).scalar_one_or_none()


async def _segments(db: AsyncSession, loop_id: uuid.UUID) -> list[GrowthSegment]:
    rows = (await db.execute(select(GrowthSegment).where(
        GrowthSegment.loop_id == loop_id).order_by(GrowthSegment.created_at)
    )).scalars().all()
    return list(rows)


async def _variants(db: AsyncSession, loop_id: uuid.UUID) -> list[GrowthVariant]:
    rows = (await db.execute(select(GrowthVariant).where(
        GrowthVariant.loop_id == loop_id).order_by(GrowthVariant.created_at)
    )).scalars().all()
    return list(rows)


async def _analysis_for(db: AsyncSession, campaign: Campaign) -> PostAnalysis | None:
    return (await db.execute(select(PostAnalysis).where(
        PostAnalysis.url == campaign.post_url))).scalar_one_or_none()


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ============================================================ AUDIENCE AGENT
def _ai_segment_specs(ai_segments: list[dict]) -> list[dict]:
    """Normalize validated AI segment dicts to the internal segment spec shape."""
    specs = []
    for s in ai_segments:
        markets = [m.strip() for m in s["markets"].split(",") if m.strip()] \
            or ["worldwide"]
        specs.append({
            "name": s["name"],
            "topics": s["topics"],
            "languages": [] if s["language"] in ("", "unknown") else [s["language"]],
            "markets": markets,
            # AI "boost" (0.5..2.0 multiplier) → mild prior in heuristic range.
            "prior_score": round(min(max(s["boost"] / 2.0, 0.25), 0.9), 3),
            "reasons": [
                s["reason"],
                "Proposed by the AI provider from the post content, topics, "
                "language, and campaign markets — real interaction data moves "
                "it up or down each round.",
            ],
        })
    return specs


async def audience_plan(campaign: Campaign, placement_topics: list[str],
                        analysis: PostAnalysis | None) -> tuple[list[dict], dict | None]:
    """Identify suitable audience segments.

    Tries the modular AI provider first; falls back to the deterministic
    heuristic planner on any failure. Returns (specs, ai_meta) where ai_meta
    is None when heuristics were used.
    """
    lang = (analysis.language if analysis else "unknown") or "unknown"
    markets = [m.strip() for m in (campaign.markets or "worldwide").split(",")
               if m.strip()] or ["worldwide"]
    ai_segments = await audience_segments_via_ai(
        campaign, analysis, placement_topics or [], ", ".join(markets), lang)
    if ai_segments is not None:
        return _ai_segment_specs(ai_segments), ai_source_meta()
    return _audience_plan_heuristic(campaign, placement_topics, analysis), None


def _audience_plan_heuristic(campaign: Campaign, placement_topics: list[str],
                             analysis: PostAnalysis | None) -> list[dict]:
    """Identify suitable audience segments. Pure, explainable heuristics v1."""
    lang = (analysis.language if analysis else "unknown") or "unknown"
    markets = [m.strip() for m in (campaign.markets or "worldwide").split(",") if m.strip()] \
        or ["worldwide"]
    langs = [] if lang in ("unknown", "") else [lang]

    topics = placement_topics or []
    segments: list[dict] = []
    if not topics:
        segments.append({
            "name": "Broad discovery audience",
            "topics": [], "languages": langs, "markets": markets,
            "prior_score": 0.5,
            "reasons": [
                "No specific topics were chosen for this placement, so the "
                "engine starts with broad distribution across the discovery feed.",
                f"Language signal: {lang}; markets: {', '.join(markets)}.",
            ],
        })
        return segments

    # One segment per topic cluster (pairs keep the count manageable).
    for i in range(0, len(topics), 2):
        chunk = topics[i:i + 2]
        prior = round(min(0.5 + 0.07 * len(chunk), 0.72), 3)
        segments.append({
            "name": f"{'/'.join(chunk)} lovers",
            "topics": chunk, "languages": langs, "markets": markets,
            "prior_score": prior,
            "reasons": [
                f"Post topics {chunk} directly match users who opted in to these interests.",
                f"Language signal from post analysis: {lang}.",
                f"Campaign markets: {', '.join(markets)}.",
                "Prior is a mild heuristic starting point — real interaction "
                "data will move it up or down each round.",
            ],
        })
    return segments[:4]


# ============================================================= CONTENT AGENT
_CTA = {
    "reach": "Know someone this would help? Share it with them.",
    "engagement": "What's your take? Drop it in the comments.",
    "profile_visits": "More where this came from — on my profile.",
    "website_traffic": "Link in bio to learn more.",
    "leads": "Link in bio if you want the details.",
    "customers": "Link in bio to get started.",
}


def _ai_variant_specs(ai_variants: list[dict]) -> list[dict]:
    """Normalize validated AI variant dicts to the internal variant spec shape."""
    specs = []
    for v in ai_variants:
        specs.append({
            "label": v["label"],
            "kind": "caption",
            "content": {
                "title": v["title"],
                "caption": v["caption"],
                "hooks": [],
                "hashtags": v["hashtags"],
                "thumbnail_brief": v["thumbnail_brief"],
                "posting_windows": [v["posting_window"]] if v["posting_window"] else [],
            },
            "rationale": v["rationale"],
            "is_original": v["label"].strip().lower() == "original (creator's version)",
        })
    # The creator's original must always be the baseline.
    if specs and not any(s["is_original"] for s in specs):
        specs[0]["is_original"] = True
        specs[0]["label"] = "Original (creator's version)"
    return specs


async def content_variants(campaign: Campaign, analysis: PostAnalysis | None,
                           max_variants: int = 4) -> tuple[list[dict], dict | None]:
    """Propose content variations.

    Tries the modular AI provider first; falls back to the deterministic
    template planner on any failure. Returns (specs, ai_meta) where ai_meta
    is None when templates were used.
    """
    goal = campaign.goal.value if hasattr(campaign.goal, "value") \
        else str(campaign.goal or "")
    ai_variants = await content_variants_via_ai(campaign, analysis,
                                                goal or "engagement")
    if ai_variants is not None:
        return _ai_variant_specs(ai_variants)[:max_variants], ai_source_meta()
    return _content_variants_heuristic(campaign, analysis, max_variants), None


def _content_variants_heuristic(campaign: Campaign, analysis: PostAnalysis | None,
                                max_variants: int = 4) -> list[dict]:
    """Propose content variations. Template-based v1, each with a rationale."""
    title = campaign.title or "My post"
    hashtags = list(dict.fromkeys(analysis.hashtags if analysis else []))[:8]
    goal = campaign.goal.value if hasattr(campaign.goal, "value") else str(campaign.goal or "")
    cta = _CTA.get(goal, _CTA["engagement"])
    platform = campaign.platform or "social"

    variants = [{
        "label": "Original (creator's version)",
        "kind": "caption",
        "content": {
            "title": title, "caption": title,
            "hooks": [], "hashtags": hashtags,
            "thumbnail_brief": "", "posting_windows": [],
        },
        "rationale": "The creator's own version is always the baseline — "
                     "every AI suggestion is measured against it, never assumed better.",
        "is_original": True,
    }]
    if max_variants > 1:
        variants.append({
            "label": "Hook-first caption",
            "kind": "caption",
            "content": {
                "title": title,
                "caption": f"{title}\n\n{cta}",
                "hooks": [title,
                          f"Why {title.lower()} matters",
                          f"My honest take: {title.lower()}"],
                "hashtags": hashtags,
                "thumbnail_brief": (
                    f"First frame shows the subject clearly; bold on-image text "
                    f"with the hook; high contrast for {platform} feeds."),
                "posting_windows": ["12:00–14:00", "19:00–22:00"],
            },
            "rationale": "Puts the hook and a clear call-to-action up front; "
                         "posting windows are general high-activity hours — tune "
                         "from your own analytics.",
            "is_original": False,
        })
    if max_variants > 2:
        variants.append({
            "label": "Question hook",
            "kind": "caption",
            "content": {
                "title": title,
                "caption": f"Have you tried this? {title}\n\n{cta}",
                "hooks": [f"Have you tried this?",
                          f"What would you do about {title.lower()}?"],
                "hashtags": hashtags,
                "thumbnail_brief": "Question text overlay on the thumbnail to invite curiosity.",
                "posting_windows": ["18:00–21:00"],
            },
            "rationale": "Questions invite genuine replies, which the Performance "
                         "agent measures as saves/visits — not vanity metrics.",
            "is_original": False,
        })
    if max_variants > 3:
        variants.append({
            "label": "Minimalist caption",
            "kind": "caption",
            "content": {
                "title": title, "caption": title,
                "hooks": [title], "hashtags": hashtags[:4],
                "thumbnail_brief": "Clean thumbnail, no text clutter; let the content speak.",
                "posting_windows": ["12:00–14:00"],
            },
            "rationale": "Tests whether fewer hashtags and a clean caption "
                         "perform better for this audience.",
            "is_original": False,
        })
    return variants[:max_variants]


def iterate_variant(base: GrowthVariant, n: int) -> dict:
    """Learning agent asked for a fresh variant: small honest iteration."""
    content = dict(base.content or {})
    caption = content.get("caption", "")
    return {
        "label": f"Iteration {n} (from '{base.label}')",
        "kind": base.kind,
        "content": {**content,
                    "caption": f"{caption}\n\n(P.S. — what part resonated most?)".strip()},
        "rationale": f"Previous best ('{base.label}') held for several rounds, so the "
                     f"engine tries one small variation instead of standing still.",
        "is_original": False,
    }


# ======================================================== DISTRIBUTION AGENT
async def apply_weights(db: AsyncSession, loop: GrowthLoop,
                        seg_weights: dict[uuid.UUID, float],
                        var_weights: dict[uuid.UUID, float],
                        round_n: int, reasons: list[str]) -> None:
    """Persist new distribution weights (segments = feed ranking multiplier,
    variants = rotation share)."""
    before_s, after_s, before_v, after_v = {}, {}, {}, {}
    for s in await _segments(db, loop.id):
        if s.id in seg_weights:
            before_s[str(s.id)] = round(s.weight, 3)
            s.weight = max(0.2, min(2.0, seg_weights[s.id]))
            after_s[str(s.id)] = round(s.weight, 3)
    total = sum(var_weights.values()) or 1.0
    for v in await _variants(db, loop.id):
        if v.id in var_weights:
            before_v[str(v.id)] = round(v.weight, 3)
            v.weight = max(0.02, var_weights[v.id] / total)
            after_v[str(v.id)] = round(v.weight, 3)
    await _decision(db, loop.id, round_n, "distribution", "weights_updated", {
        "reasons": reasons,
        "before": {"segments": before_s, "variants": before_v},
        "after": {"segments": after_s, "variants": after_v},
    })


# ========================================================= PERFORMANCE AGENT
async def _open_fraud(db: AsyncSession, campaign_id: uuid.UUID) -> bool:
    row = (await db.execute(select(FraudFlag).where(
        FraudFlag.campaign_id == campaign_id,
        FraudFlag.resolved.is_(False)).limit(1))).scalar_one_or_none()
    return row is not None


async def measure(db: AsyncSession, loop: GrowthLoop,
                  round_start: datetime) -> dict:
    """Aggregate genuine interactions since round_start.

    - per variant: direct counts via stored variant_id (what was displayed)
    - per segment: fractional attribution via each user's opted-in interests
    Returns metrics + safety signals. Writes GrowthObservation rows + a
    performance decision.
    """
    campaign_id = loop.campaign_id
    rows = (await db.execute(select(DiscoveryInteraction).where(
        DiscoveryInteraction.campaign_id == campaign_id,
        DiscoveryInteraction.created_at >= round_start))).scalars().all()

    fraud_open = await _open_fraud(db, campaign_id)

    # interaction kinds are singular ("view"); count buckets use plural keys
    KIND2KEY = {"view": "views", "save": "saves",
                "visit": "visits", "dismiss": "dismissals"}
    variants = await _variants(db, loop.id)
    v_counts: dict[uuid.UUID, dict] = {
        v.id: {"views": 0, "saves": 0, "visits": 0, "dismissals": 0}
        for v in variants}
    unattributed = {"views": 0, "saves": 0, "visits": 0, "dismissals": 0}
    user_ids = {r.user_id for r in rows}
    interests: dict[uuid.UUID, set[str]] = {}
    for uid in user_ids:
        interests[uid] = set(await get_my_interests(db, uid))

    segments = [s for s in await _segments(db, loop.id) if s.status == "active"]
    s_counts: dict[uuid.UUID, dict] = {
        s.id: {"views": 0.0, "saves": 0.0, "visits": 0.0, "dismissals": 0.0}
        for s in segments}

    for r in rows:
        key = KIND2KEY.get(r.kind)
        if key is None:
            continue
        # --- variant attribution (direct: what was actually displayed)
        if r.variant_id in v_counts:
            v_counts[r.variant_id][key] += 1
        else:
            unattributed[key] += 1
        # --- segment attribution (fractional via user interests)
        user_topics = interests.get(r.user_id, set())
        matching = [s for s in segments
                    if not s.topics or (set(s.topics) & user_topics)]
        if matching:
            share = 1.0 / len(matching)
            for s in matching:
                s_counts[s.id][key] += share

    # persist observations
    for vid, c in v_counts.items():
        db.add(GrowthObservation(loop_id=loop.id, round=loop.round + 1,
                                 variant_id=vid, attribution="direct", **c))
    for sid, c in s_counts.items():
        db.add(GrowthObservation(
            loop_id=loop.id, round=loop.round + 1, segment_id=sid,
            attribution="fractional",
            views=round(c["views"]), saves=round(c["saves"]),
            visits=round(c["visits"]), dismissals=round(c["dismissals"])))

    totals = {"views": 0, "saves": 0, "visits": 0, "dismissals": 0}
    for c in list(v_counts.values()) + [unattributed]:
        for k in totals:
            totals[k] += c[k]

    metrics = {
        "window_since": round_start.isoformat(),
        "interactions": len(rows),
        "totals": totals,
        "by_variant": {str(vid): c for vid, c in v_counts.items()},
        "by_segment": {str(sid): {k: round(v, 2) for k, v in c.items()}
                       for sid, c in s_counts.items()},
        "unattributed": unattributed,
        "fraud_flag_open": fraud_open,
    }
    await _decision(db, loop.id, loop.round + 1, "performance",
                    "round_measured", {
                        "reasons": [
                            "Counts come only from genuine discovery interactions "
                            "(view/save/visit/dismiss by real opted-in users).",
                            "Variant counts are direct (the variant actually displayed).",
                            "Segment counts are fractional attribution via each "
                            "user's own interest opt-ins.",
                            "No impressions, views, or engagement are ever fabricated.",
                        ],
                        "metrics": metrics,
                    })
    return metrics


# ============================================================ LEARNING AGENT
def _score(counts: dict, prior: float, prior_n: float = 10.0) -> float:
    """Smoothed segment/variant score: saves and visits good, dismissals bad."""
    views = float(counts.get("views", 0))
    saves = float(counts.get("saves", 0))
    visits = float(counts.get("visits", 0))
    dismissals = float(counts.get("dismissals", 0))
    positives = 0.5 * saves + 0.3 * visits + 0.2 * max(views - dismissals, 0)
    return (positives + prior * prior_n) / (views + prior_n)


def _softmax(scores: list[float], temperature: float) -> list[float]:
    m = max(scores) if scores else 0
    exps = [math.exp((s - m) / max(temperature, 0.05)) for s in scores]
    total = sum(exps) or 1.0
    return [e / total for e in exps]


async def learn(db: AsyncSession, loop: GrowthLoop, metrics: dict) -> dict:
    """Decide new weights, pauses, and fresh variants. Returns a summary."""
    cfg = {**DEFAULT_CONFIG, **(loop.config or {})}
    explore = float(cfg["explore_floor"])
    temp = float(cfg["temperature"])
    min_views = int(cfg["min_views"])
    dismiss_pause = float(cfg["dismiss_pause_rate"])
    round_n = loop.round + 1
    changes: list[str] = []

    # ---- safety first
    if metrics.get("fraud_flag_open"):
        loop.status = "paused"
        await _decision(db, loop.id, round_n, "learning", "loop_paused_safety", {
            "reasons": ["An open fraud flag exists for this campaign. The engine "
                        "pauses distribution rather than optimizing on "
                        "suspicious traffic. Resolve the flag to resume."],
        })
        await _audit(db, loop.user_id, "growth.loop.auto_pause",
                     f"loop={loop.id} reason=fraud_flag")
        return {"paused": True, "reason": "fraud_flag_open", "changes": changes}

    totals = metrics["totals"]
    if totals["views"] >= 50 and totals["views"] > 0 and \
            totals["dismissals"] / totals["views"] > 0.7:
        loop.status = "paused"
        await _decision(db, loop.id, round_n, "learning", "loop_paused_safety", {
            "reasons": [f"Dismissal rate {totals['dismissals']/totals['views']:.0%} "
                        "across the loop suggests a content/audience mismatch. "
                        "Distribution paused — review the content before resuming."],
        })
        await _audit(db, loop.user_id, "growth.loop.auto_pause",
                     f"loop={loop.id} reason=high_dismiss_rate")
        return {"paused": True, "reason": "high_dismiss_rate", "changes": changes}

    segments = await _segments(db, loop.id)
    variants = await _variants(db, loop.id)
    active_segs = [s for s in segments if s.status == "active"]
    active_vars = [v for v in variants if v.status == "active"]

    # ---- segment scores → weights (feed ranking multipliers, mean ≈ 1)
    seg_scores = []
    for s in active_segs:
        c = metrics["by_segment"].get(str(s.id), {})
        seg_scores.append(_score(c, s.prior_score))
    if active_segs:
        shares = _softmax(seg_scores, temp)
        n = len(active_segs)
        seg_weights = {s.id: max(0.2, min(2.0, (1 - explore) * n * sh + explore * 1.0))
                       for s, sh in zip(active_segs, shares)}
    else:
        seg_weights = {}

    # ---- pause poorly-received segments
    for s in active_segs:
        c = metrics["by_segment"].get(str(s.id), {})
        views = float(c.get("views", 0))
        dr = (float(c.get("dismissals", 0)) / views) if views else 0
        if views >= min_views and dr >= dismiss_pause:
            s.status = "paused"
            changes.append(f"Segment '{s.name}' paused: {dr:.0%} dismiss rate "
                           f"over {views:.0f} views.")
            await _decision(db, loop.id, round_n, "learning", "segment_paused", {
                "reasons": [f"Dismiss rate {dr:.0%} ≥ {dismiss_pause:.0%} with "
                            f"{views:.0f} views — this audience is signaling "
                            "the content isn't for them."],
                "metrics": {"dismiss_rate": round(dr, 3), "views": views},
            })

    # ---- variant scores → rotation shares
    var_scores = []
    for v in active_vars:
        c = metrics["by_variant"].get(str(v.id), {})
        var_scores.append(_score(c, 0.5))
    if active_vars:
        shares = _softmax(var_scores, temp)
        var_weights = {v.id: max(0.02, (1 - explore) * sh + explore / len(active_vars))
                       for v, sh in zip(active_vars, shares)}
    else:
        var_weights = {}

    reasons = [
        "Weights follow smoothed performance (saves 50%, visits 30%, "
        "non-dismissed views 20%) with Laplace smoothing toward each "
        "segment's prior — small samples can't swing wildly.",
        f"{explore:.0%} of distribution is always kept exploring so no "
        "segment or variant starves completely.",
        "Softmax reallocation is gradual: winners earn more genuine "
        "exposure, losers fade — nothing is ever faked to look better.",
    ]
    await apply_weights(db, loop, seg_weights, var_weights, round_n, reasons)
    changes.append("Distribution weights updated from measured performance.")

    # ---- stagnation → ask content agent for a fresh variant
    state = dict((loop.config or {}).get("_state", {}))
    best_var = max(active_vars, key=lambda v: var_scores[active_vars.index(v)],
                   default=None) if active_vars else None
    if best_var is not None:
        prev_best = state.get("best_variant")
        state["stagnant_rounds"] = state.get("stagnant_rounds", 0) + 1 \
            if prev_best == str(best_var.id) else 0
        state["best_variant"] = str(best_var.id)
        if state["stagnant_rounds"] >= 3 and len(variants) < int(cfg["max_variants"]):
            spec = iterate_variant(best_var, len(variants))
            db.add(GrowthVariant(loop_id=loop.id, label=spec["label"],
                                 kind=spec["kind"], content=spec["content"],
                                 rationale=spec["rationale"], weight=0.1))
            state["stagnant_rounds"] = 0
            changes.append(f"New variant '{spec['label']}' added — best variant "
                           "held for 3 rounds.")
            await _decision(db, loop.id, round_n, "content", "variant_added", {
                "reasons": [spec["rationale"]],
            })
    loop.config = {**(loop.config or {}), "_state": state}

    # ---- official platform metrics (if the creator supplied any): shown as
    # labeled context only — never mixed into genuine-engagement accounting.
    platform_context = await _platform_context(db, loop.campaign_id, totals)
    if platform_context is not None:
        changes.append("Official platform snapshots on file — shown separately "
                       "below; distribution still follows genuine Discovery "
                       "interactions only.")

    await _decision(db, loop.id, round_n, "learning", "round_learned", {
        "reasons": changes or ["No structural changes this round — weights adjusted."],
        "metrics": {"segment_scores": {str(s.id): round(sc, 3)
                                       for s, sc in zip(active_segs, seg_scores)},
                    "variant_scores": {str(v.id): round(sc, 3)
                                       for v, sc in zip(active_vars, var_scores)}},
        **({"platform_context": platform_context} if platform_context else {}),
    })
    return {"paused": False, "changes": changes}


async def _platform_context(db: AsyncSession, campaign_id: uuid.UUID,
                            discovery_totals: dict) -> dict | None:
    """Fetch official platform snapshots for the campaign and blend them with
    Discovery totals into clearly separated buckets. Returns None when the
    creator has not supplied any platform data."""
    from app.models.social_metrics import SocialMetricSnapshot  # lazy: avoid cycles
    from app.services.social_metrics import blend_platform_metrics
    rows = (await db.execute(
        select(SocialMetricSnapshot)
        .where(SocialMetricSnapshot.campaign_id == campaign_id)
        .order_by(SocialMetricSnapshot.captured_at))).scalars().all()
    if not rows:
        return None
    snapshots = []
    for r in rows:
        m = dict(r.metrics or {})
        m.update({"platform": r.platform, "source": r.source,
                  "captured_at": r.captured_at.isoformat()
                  if r.captured_at else ""})
        snapshots.append(m)
    return blend_platform_metrics(discovery_totals, snapshots)


# ============================================================ LOOP LIFECYCLE
async def start_loop(db: AsyncSession, user: User, campaign_id: uuid.UUID,
                     config: dict | None = None) -> GrowthLoop:
    """Analyze → audience match → content variants → initial distribution."""
    campaign = (await db.execute(select(Campaign).where(
        Campaign.id == campaign_id, Campaign.user_id == user.id)
    )).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Campaign not found")
    if campaign.status not in (CampaignStatus.live, CampaignStatus.optimizing):
        raise ValueError("Growth Engine needs a live campaign")

    existing = await get_loop_for_campaign(db, campaign_id)
    if existing is not None:
        return existing

    cfg = {**DEFAULT_CONFIG, **(config or {})}

    # Ensure discovery placement (initial distribution channel).
    placement = (await db.execute(select(DiscoveryPlacement).where(
        DiscoveryPlacement.campaign_id == campaign_id))).scalar_one_or_none()
    if placement is None:
        status = "awaiting_approval"
        placement_note = ("No discovery placement exists yet — opt this campaign "
                          "into the Discovery Platform and pick topics; the engine "
                          "starts distributing once the placement is approved.")
    elif placement.status != "approved":
        status = "awaiting_approval"
        placement_note = (f"Placement is '{placement.status}' — the loop will start "
                          "distributing once it is approved.")
    else:
        status = "running"
        placement_note = "Placement approved — initial distribution started."

    analysis = await _analysis_for(db, campaign)
    topics = placement.topics if placement is not None else []

    loop = GrowthLoop(campaign_id=campaign_id, user_id=user.id, status=status,
                      config=cfg)
    db.add(loop)
    await db.flush()  # need loop.id

    # Audience agent → segments (AI provider first, heuristics on failure)
    seg_specs, seg_meta = await audience_plan(campaign, topics, analysis)
    for spec in seg_specs:
        db.add(GrowthSegment(loop_id=loop.id, name=spec["name"],
                             topics=spec["topics"], languages=spec["languages"],
                             markets=spec["markets"], prior_score=spec["prior_score"],
                             weight=1.0))
    # Content agent → variants (AI provider first, templates on failure)
    var_specs, var_meta = await content_variants(campaign, analysis,
                                                max_variants=int(cfg["max_variants"]))
    for spec in var_specs:
        db.add(GrowthVariant(loop_id=loop.id, label=spec["label"],
                             kind=spec["kind"], content=spec["content"],
                             rationale=spec["rationale"],
                             is_original=spec["is_original"], weight=1.0))
    await db.flush()

    n_seg = len(await _segments(db, loop.id))
    n_var = len(await _variants(db, loop.id))
    # Distribution agent → initial equal weights
    await apply_weights(
        db, loop,
        {s.id: 1.0 for s in await _segments(db, loop.id)},
        {v.id: 1.0 for v in await _variants(db, loop.id)},
        0,
        ["Initial distribution is even across segments and variants — the "
         "engine explores first, then lets measured performance decide."],
    )
    seg_reasons = [f"{n_seg} audience segment(s) identified from post topics, "
                   "language, hashtags, and campaign markets."]
    seg_details: dict = {"reasons": seg_reasons}
    if seg_meta is not None:
        seg_details.update(seg_meta)
        if seg_meta.get("dev"):
            seg_reasons.append("(development output — not real analysis)")
    await _decision(db, loop.id, 0, "audience", "segments_identified", seg_details)
    var_reasons = [f"{n_var} content variant(s) proposed (creator's original + "
                   "AI suggestions). AI variants rotate in the discovery feed "
                   "only with the creator's opt-in."]
    var_details: dict = {"reasons": var_reasons}
    if var_meta is not None:
        var_details.update(var_meta)
        if var_meta.get("dev"):
            var_reasons.append("(development output — not real analysis)")
    await _decision(db, loop.id, 0, "content", "variants_proposed", var_details)
    await _decision(db, loop.id, 0, "system", "loop_started", {
        "reasons": [placement_note, DISCLAIMER],
    })
    await _audit(db, user.id, "growth.loop.start", f"loop={loop.id} campaign={campaign_id}")
    await db.commit()
    await db.refresh(loop)
    return loop


async def run_round(db: AsyncSession, loop_id: uuid.UUID) -> dict:
    """One full measure → learn → optimize cycle for a running loop."""
    loop = await get_loop(db, loop_id)
    if loop is None:
        raise ValueError("Loop not found")

    # Placement must be approved before any distribution.
    placement = (await db.execute(select(DiscoveryPlacement).where(
        DiscoveryPlacement.campaign_id == loop.campaign_id))).scalar_one_or_none()
    if placement is None or placement.status != "approved":
        if loop.status == "running":
            loop.status = "awaiting_approval"
            await _decision(db, loop.id, loop.round, "system",
                            "distribution_held", {
                                "reasons": ["Discovery placement is not approved — "
                                            "the engine holds distribution rather "
                                            "than pushing content anywhere else."],
                            })
            await db.commit()
        return {"loop_id": str(loop.id), "status": loop.status,
                "note": "awaiting placement approval"}

    if loop.status == "awaiting_approval":
        loop.status = "running"
        await _decision(db, loop.id, loop.round, "system", "loop_running", {
            "reasons": ["Placement approved — distribution started."],
        })

    if loop.status != "running":
        return {"loop_id": str(loop.id), "status": loop.status,
                "note": "loop not running; round skipped"}

    round_n = loop.round + 1
    # Measure everything since the previous round ended (or loop creation).
    if loop.round == 0:
        round_start = loop.created_at or _now()
    else:
        prev = (await db.execute(select(GrowthRound).where(
            GrowthRound.loop_id == loop.id,
            GrowthRound.number == loop.round))).scalar_one_or_none()
        round_start = (prev.ended_at or prev.started_at or loop.created_at
                       or _now()) if prev else (loop.created_at or _now())
    rnd = GrowthRound(loop_id=loop.id, number=round_n)
    db.add(rnd)
    await db.flush()

    metrics = await measure(db, loop, round_start)
    learned = await learn(db, loop, metrics)

    rnd.summary = {"metrics": metrics["totals"], "changes": learned["changes"],
                   "paused": learned["paused"]}
    rnd.ended_at = _now()
    if not learned["paused"]:
        loop.round = round_n
    await db.commit()
    return {"loop_id": str(loop.id), "round": round_n, "status": loop.status,
            "changes": learned["changes"]}


async def set_loop_status(db: AsyncSession, user: User, loop_id: uuid.UUID,
                          status: str) -> GrowthLoop:
    if status not in ("running", "paused", "stopped"):
        raise ValueError("status must be running|paused|stopped")
    loop = await get_loop(db, loop_id)
    if loop is None or loop.user_id != user.id:
        raise ValueError("Loop not found")
    loop.status = status
    await _decision(db, loop.id, loop.round, "system", f"loop_{status}", {
        "reasons": [f"Creator set the loop to '{status}'."],
    })
    await _audit(db, user.id, f"growth.loop.{status}", f"loop={loop.id}")
    await db.commit()
    return loop


# ============================================================ FEED INTEGRATION
async def loop_context(db: AsyncSession, campaign_id: uuid.UUID) -> dict | None:
    """Active loop + segments + variants for feed-time personalization."""
    loop = await get_loop_for_campaign(db, campaign_id)
    if loop is None or loop.status != "running":
        return None
    if not loop.config.get("auto_apply_variants", True):
        return {"loop": loop, "segments": await _segments(db, loop.id),
                "variants": []}
    return {"loop": loop, "segments": await _segments(db, loop.id),
            "variants": await _variants(db, loop.id)}


def segment_boost(segments: list[GrowthSegment], user_topics: set[str],
                  ) -> tuple[float, uuid.UUID | None]:
    """Which segment does this user belong to, and its ranking multiplier?"""
    best: GrowthSegment | None = None
    for s in segments:
        if s.status != "active":
            continue
        if not s.topics or (set(s.topics) & user_topics):
            if best is None or s.weight > best.weight:
                best = s
    if best is None:
        return 1.0, None
    return max(0.2, min(2.0, best.weight)), best.id


def pick_variant(variants: list[GrowthVariant], user_id: uuid.UUID,
                 campaign_id: uuid.UUID) -> GrowthVariant | None:
    """Deterministic weighted rotation: a user consistently sees one variant."""
    active = [v for v in variants if v.status == "active"]
    if not active:
        return None
    total = sum(v.weight for v in active) or 1.0
    h = int(hashlib.sha256(
        f"{user_id}:{campaign_id}".encode()).hexdigest(), 16)
    x = (h % 10000) / 10000 * total
    acc = 0.0
    for v in active:
        acc += v.weight
        if x <= acc:
            return v
    return active[-1]


# ------------------------------------------------------------------ celery
@celery.task(name="virello.growth.tick")
def tick_growth_loops() -> dict:
    """Beat task: run a round for every running loop whose round is due."""
    async def _go() -> dict:
        ran = []
        async for db in get_db():
            loops = (await db.execute(select(GrowthLoop).where(
                GrowthLoop.status == "running"))).scalars().all()
            for loop in loops:
                hours = float((loop.config or {}).get(
                    "round_hours", DEFAULT_CONFIG["round_hours"]))
                updated = loop.updated_at or loop.created_at
                age_h = (_now() - updated).total_seconds() / 3600 if updated else 999
                if age_h >= hours:
                    ran.append(await run_round(db, loop.id))
        return {"ran": ran, "count": len(ran)}
    return _await_sync(_go())


def _await_sync(coro):
    """Run a coroutine from sync Celery task code."""
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    else:
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            return pool.submit(lambda: asyncio.run(coro)).result()
