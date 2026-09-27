"""AI Distribution & Optimization Agents — the autonomous closed loop.

Two agents, one per plan (see app.services.growth_agents):
- Free Grow AI ("free_growth_agent") manages Free Grow campaigns: organic
  discovery, worldwide, zero budget. Near the free impression cap it winds
  down expansion and says so honestly.
- Paid Boost AI ("paid_growth_agent") manages Paid Boost campaigns: adds
  budget pacing guardrails, cost-efficiency tuning, and geo awareness.

Post Upload → Content Analysis → Audience Intelligence → Audience Matching →
Campaign Setup → Initial Distribution → Real User Signals → Performance
Analysis → AI Optimization → Continued Distribution.

The optimizer reads ONLY aggregate counts from ``ad_impressions`` (genuine
measured events — never estimates, never private user data) and adjusts
distribution within the advertiser-approved budget:

- reduce weight / soften weak segments (with a strict minimum-sample guard —
  never decide on tiny samples),
- expand weight of strong segments (capped, budget-aware),
- rotate/test creative variants via deterministic weighted rotation,
- compare placements and shift weight toward better-performing placements.

Safety mirrors the growth engine's fraud-flag pattern: suspicious traffic
(impossible ratios, event bursts, frequency-cap circumvention) auto-pauses
the campaign instead of being optimized on.

Budget guardrails: the optimizer NEVER raises spend — it only reweights
distribution. All spend remains hard-clamped by ad_distribution.

Every decision is persisted as an AdDecision row (agent="free_growth_agent"
or "paid_growth_agent", chosen by the campaign's plan) with reasons,
before/after metrics, and the honesty disclaimer — nothing is a black box.

AI provider: proposals are requested through app.services.ads_ai with the
same never-raises contract as growth_ai/ads_ai — strict JSON validation,
heuristic fallback on ANY failure. Decisions record which source was used.
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
from app.core.database import get_db
from app.models.ad_delivery import (
    AdBudget,
    AdEventType,
    AdImpression,
    AdPlacement,
    PlacementStatus,
)
from app.models.ad_optimization import (
    AdOptimizationRun,
    AdSegmentWeight,
    AdVariant,
    OptimizationRunStatus,
    VariantStatus,
)
from app.models.ads import (
    AdCampaign,
    AdCampaignStatus,
    AdDecision,
    AudienceSegment,
)
from app.services.ads_ai import ai_source_meta, propose_optimization_via_ai
from app.services import geo as geo_svc
from app.services import growth_agents as agents_svc
from app.services import plans as plans_svc

DISCLAIMER = (
    "Optimization is estimated guidance only — Virello never guarantees "
    "reach, engagement, followers, leads, or sales. All figures come from "
    "genuine measured events, never inflated.")

# ------------------------------------------------------------------ config
#: Minimum genuine impressions before a segment/variant/placement may get
#: any adjustment beyond "keep". Decisions on smaller samples would be
#: noise — the optimizer says so explicitly instead of acting.
MIN_IMPRESSIONS = 50
#: Stronger guard before any pause-like action (weight floor / placement
#: pause): pausing on a small sample would silence a segment unfairly.
MIN_IMPRESSIONS_PAUSE = 100

#: Engagement-rate bands (engagements = like+save+click+follow per impression).
WEAK_RATE = 0.01    # below this (with enough sample) → weight reduced
PAUSE_RATE = 0.002  # below this (with pause-level sample) → weight floored
STRONG_RATE = 0.05  # above this (with enough sample) → weight expanded

EXPLORE_FLOOR = 0.15   # share of weight always kept exploring
MIN_WEIGHT = 0.2
MAX_WEIGHT = 2.0
TEMPERATURE = 0.7      # softmax temperature for placement reallocation

#: Fraud heuristics (aggregate signals only — no private user data).
BURST_EVENTS = 30          # events from one viewer in the window
IMPOSSIBLE_RATIO = 1.0     # views can never exceed impressions

#: Scheduler cadence guard: don't re-optimize more often than this.
OPTIMIZE_INTERVAL_HOURS = 6


# ------------------------------------------------------------------ helpers
def _now() -> datetime:
    return datetime.now(timezone.utc)


def _clamp_weight(w: float) -> float:
    return max(MIN_WEIGHT, min(MAX_WEIGHT, w))


async def _decision(db: AsyncSession, campaign: AdCampaign, agent: str,
                    action: str, reasons: list[str], metrics: dict) -> None:
    """Persist one audited decision. Every decision carries the campaign's
    geo context (mode + effective countries) so targeting is never a
    black box."""
    db.add(AdDecision(
        campaign_id=campaign.id, agent=agent, action=action,
        details={"reasons": reasons, "metrics": metrics,
                 "geo": geo_svc.geo_context(campaign),
                 "disclaimer": DISCLAIMER}))


def _softmax(scores: list[float], temperature: float) -> list[float]:
    m = max(scores) if scores else 0.0
    exps = [math.exp((s - m) / max(temperature, 0.05)) for s in scores]
    total = sum(exps) or 1.0
    return [e / total for e in exps]


def pick_variant(variants: list[AdVariant], user_id: uuid.UUID,
                 campaign_id: uuid.UUID) -> AdVariant | None:
    """Deterministic weighted rotation: a viewer consistently sees one
    variant, and over the audience the rotation follows the optimizer's
    weights. Mirrors growth_engine.pick_variant."""
    active = [v for v in variants if v.status == VariantStatus.active]
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


# ------------------------------------------------------------------ measurement
ENGAGEMENT_TYPES = {AdEventType.like, AdEventType.save, AdEventType.click,
                    AdEventType.follow}


async def _measure(db: AsyncSession, campaign_id: uuid.UUID) -> dict:
    """Aggregate genuine events per segment / variant / placement.

    Returns {"by_segment": {sid: counts}, "by_variant": {vid: counts},
    "by_placement": {pid: counts}, "totals": counts, "viewer_events": {uid: n},
    "viewer_impressions": {uid: n}} where counts =
    {impressions, views, engagements, clicks, visits}.
    """
    rows = (await db.execute(select(AdImpression).where(
        AdImpression.campaign_id == campaign_id))).scalars().all()

    def _new() -> dict:
        return {"impressions": 0, "views": 0, "engagements": 0, "clicks": 0,
                "visits": 0}

    by_segment: dict[str, dict] = {}
    by_variant: dict[str, dict] = {}
    by_placement: dict[str, dict] = {}
    totals = _new()
    viewer_events: dict[str, int] = {}
    viewer_impressions: dict[str, int] = {}

    for r in rows:
        key = r.event_type.value
        buckets = [totals]
        if r.segment_id is not None:
            buckets.append(by_segment.setdefault(str(r.segment_id), _new()))
        if r.variant_id is not None:
            buckets.append(by_variant.setdefault(str(r.variant_id), _new()))
        if r.placement_id is not None:
            buckets.append(by_placement.setdefault(str(r.placement_id), _new()))
        for b in buckets:
            if r.event_type == AdEventType.impression:
                b["impressions"] += 1
            elif r.event_type == AdEventType.view:
                b["views"] += 1
            elif r.event_type in ENGAGEMENT_TYPES:
                b["engagements"] += 1
            if r.event_type == AdEventType.click:
                b["clicks"] += 1
            elif r.event_type == AdEventType.visit:
                b["visits"] += 1
        if r.viewer_user_id is not None:
            uid = str(r.viewer_user_id)
            viewer_events[uid] = viewer_events.get(uid, 0) + 1
            if r.event_type == AdEventType.impression:
                viewer_impressions[uid] = viewer_impressions.get(uid, 0) + 1

    def _rates(c: dict) -> dict:
        imp = max(c["impressions"], 1)
        return {**c,
                "engagement_rate": round(c["engagements"] / imp, 4),
                "ctr": round(c["clicks"] / imp, 4),
                "view_rate": round(min(c["views"], c["impressions"]) / imp, 4)}

    return {
        "by_segment": {k: _rates(v) for k, v in by_segment.items()},
        "by_variant": {k: _rates(v) for k, v in by_variant.items()},
        "by_placement": {k: _rates(v) for k, v in by_placement.items()},
        "totals": _rates(totals),
        "viewer_events": viewer_events,
        "viewer_impressions": viewer_impressions,
        "events_count": len(rows),
    }


# ------------------------------------------------------------------ fraud detection
def _detect_suspicious(metrics: dict, freq_cap: int) -> list[str]:
    """Aggregate-only fraud heuristics. Returns human-readable reasons."""
    reasons: list[str] = []
    totals = metrics["totals"]
    if totals["impressions"] > 0 and \
            totals["views"] > totals["impressions"] * IMPOSSIBLE_RATIO:
        reasons.append(
            f"Impossible ratio: {totals['views']} views vs "
            f"{totals['impressions']} impressions — views cannot exceed "
            "genuine impressions; traffic is fabricated or double-reported.")
    for uid, n in metrics["viewer_events"].items():
        if n >= BURST_EVENTS:
            reasons.append(
                f"Event burst: one viewer generated {n} events — "
                "consistent with automation, not genuine browsing.")
            break
    cap_limit = max(int(freq_cap or 3), 1) * 3
    for uid, n in metrics["viewer_impressions"].items():
        if n > cap_limit:
            reasons.append(
                f"Frequency-cap circumvention: one viewer shows {n} "
                f"impressions (cap is {freq_cap}) — events are being "
                "reported outside genuine serving.")
            break
    return reasons


# ------------------------------------------------------------------ structure setup
#: Geo-segment optimization bounds: per-country group multipliers applied
#: on top of the per-segment rules above. Country performance comes ONLY
#: from genuine events on segments with that DECLARED geography — viewer
#: location is never inferred (we don't have it and must not invent it).
GEO_STRONG_MULT = 1.2
GEO_WEAK_MULT = 0.8


async def _campaign_segments(db: AsyncSession,
                             campaign: AdCampaign) -> list[AudienceSegment]:
    from app.services import audience_intelligence as ai_svc
    all_active = await ai_svc.list_active_segments(db)
    if campaign.segment_ids:
        wanted = {str(s) for s in campaign.segment_ids}
        return [s for s in all_active if str(s.id) in wanted]
    return all_active


async def _optimize_geo_segments(db: AsyncSession, campaign: AdCampaign,
                                 agent: str,
                                 seg_weights: list[AdSegmentWeight],
                                 by_segment: dict,
                                 wind_down: bool,
                                 decisions: list[str]) -> int:
    """Per-country segment reweighting from genuine per-country signals.

    Segments are grouped by their DECLARED geography; each group's genuine
    engagement rate (engagements / impressions over its member segments)
    drives a bounded multiplier on the member weights. Groups below the
    minimum sample are never judged. The Free Grow wind-down still blocks
    expansion. Every group decision is audited with the geo context.
    """
    segments = {str(s.id): s for s in await _campaign_segments(db, campaign)}
    groups: dict[str, list[AdSegmentWeight]] = {}
    for row in seg_weights:
        seg = segments.get(str(row.segment_id))
        g = str(getattr(seg, "geography", "") or "").strip().upper() \
            if seg is not None else ""
        groups.setdefault(g or "GLOBAL", []).append(row)
    if len(groups) <= 1:
        return 0  # nothing country-specific to learn
    adjusted = 0
    for country in sorted(groups):
        rows = groups[country]
        imp = sum(by_segment.get(str(r.segment_id), {}).get("impressions", 0)
                  for r in rows)
        eng = sum(by_segment.get(str(r.segment_id), {}).get("engagements", 0)
                  for r in rows)
        rate = (eng / imp) if imp else 0.0
        label = ("Global (no declared geography)" if country == "GLOBAL"
                 else geo_svc.COUNTRY_NAMES.get(country, country))
        guard = (f"Minimum-sample guard: {MIN_IMPRESSIONS} genuine "
                 f"impressions per country before any geo adjustment.")
        if imp < MIN_IMPRESSIONS:
            note = (f"{label}: only {imp} genuine impressions across its "
                    f"segments — below the {MIN_IMPRESSIONS} minimum, so no "
                    f"geo adjustment. No decision is made on tiny samples.")
            action = "geo_kept_insufficient_data"
        elif rate >= STRONG_RATE and not wind_down:
            for r in rows:
                r.weight = _clamp_weight(r.weight * GEO_STRONG_MULT)
            note = (f"{label}: strong {rate:.2%} engagement over {imp} "
                    f"genuine impressions — member segment weights "
                    f"×{GEO_STRONG_MULT} (bounded).")
            action = "geo_segment_strengthened"
        elif rate >= STRONG_RATE and wind_down:
            note = (f"{label}: strong {rate:.2%} engagement over {imp} "
                    f"impressions — weights kept (winding down near the free "
                    f"limit, no expansion).")
            action = "geo_segment_kept"
        elif rate <= WEAK_RATE:
            for r in rows:
                r.weight = _clamp_weight(r.weight * GEO_WEAK_MULT)
            note = (f"{label}: weak {rate:.2%} engagement over {imp} genuine "
                    f"impressions — member segment weights ×{GEO_WEAK_MULT} "
                    f"(bounded, never below the weight floor).")
            action = "geo_segment_weakened"
        else:
            note = (f"{label}: average {rate:.2%} engagement over {imp} "
                    f"impressions — weights kept.")
            action = "geo_segment_kept"
        await _decision(
            db, campaign, agent, action,
            [note, guard,
             "Country signals come from declared segment geography only — "
             "per-viewer location is never inferred."],
            {"country": country, "segments": len(rows),
             "impressions": imp, "engagements": eng,
             "engagement_rate": round(rate, 4),
             "multiplier": (GEO_STRONG_MULT if action == "geo_segment_strengthened"
                            else GEO_WEAK_MULT if action == "geo_segment_weakened"
                            else 1.0)})
        decisions.append(note)
        if action in ("geo_segment_strengthened", "geo_segment_weakened"):
            adjusted += 1
    return adjusted
    from app.services import audience_intelligence as ai_svc
    all_active = await ai_svc.list_active_segments(db)
    if campaign.segment_ids:
        wanted = {str(s) for s in campaign.segment_ids}
        return [s for s in all_active if str(s.id) in wanted]
    return all_active


async def ensure_segment_weights(db: AsyncSession,
                                 campaign: AdCampaign) -> list[AdSegmentWeight]:
    """One AdSegmentWeight row per campaign segment (weight starts at 1.0)."""
    segments = await _campaign_segments(db, campaign)
    rows = (await db.execute(select(AdSegmentWeight).where(
        AdSegmentWeight.campaign_id == campaign.id))).scalars().all()
    have = {str(r.segment_id) for r in rows}
    for s in segments:
        if str(s.id) not in have:
            rows.append(AdSegmentWeight(
                campaign_id=campaign.id, segment_id=s.id, weight=1.0))
    db.add_all(rows)
    await db.flush()
    return rows


async def ensure_variants(db: AsyncSession,
                          campaign: AdCampaign) -> list[AdVariant]:
    """The advertiser's original is ALWAYS the baseline variant."""
    rows = (await db.execute(select(AdVariant).where(
        AdVariant.campaign_id == campaign.id)
        .order_by(AdVariant.created_at))).scalars().all()
    if not rows:
        rows.append(AdVariant(
            campaign_id=campaign.id,
            label="Original (advertiser's version)",
            kind="caption",
            content={"caption": (campaign.content_ref or "")[:500]},
            rationale=("The advertiser's own creative — always the baseline "
                       "that AI variants are measured against."),
            weight=1.0, status=VariantStatus.active, is_original=True))
        db.add_all(rows)
        await db.flush()
    return rows


def _heuristic_variant(campaign: AdCampaign) -> dict:
    """Small honest alternative when only the original has been tested."""
    base = (campaign.content_ref or "")[:500]
    return {
        "label": "Hook alternative 1",
        "kind": "hook",
        "content": {
            "hook": "A fresh opening line for the same genuine content.",
            "caption": base,
            "hashtags": [],
        },
        "rationale": ("Only the original creative has been tested so far — "
                      "adding one honest hook alternative so rotation has "
                      "something real to compare. No content is faked."),
    }


# ------------------------------------------------------------------ optimization
async def run_optimization(db: AsyncSession, campaign_id: uuid.UUID,
                           triggered_by: str = "manual") -> dict:
    """One full optimization pass. Idempotent-ish: safe to re-run; every
    decision is audited with before/after metrics."""
    campaign = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == campaign_id))).scalar_one_or_none()
    run = AdOptimizationRun(campaign_id=campaign_id,
                            triggered_by=triggered_by,
                            status=OptimizationRunStatus.completed)
    db.add(run)
    await db.flush()

    if campaign is None:
        run.status = OptimizationRunStatus.failed
        run.summary = {"error": "campaign not found"}
        await db.commit()
        raise ValueError("Ad campaign not found")

    # Each plan has its own AI agent: Free Grow AI manages free campaigns,
    # Paid Boost AI manages paid ones. The agent name goes on every audited
    # decision so the app can show who manages what.
    agent = agents_svc.agent_for_plan(campaign.plan)
    is_free = agent == agents_svc.FREE_GROWTH_AGENT

    # Budget guardrail first: never optimize spend past the approved budget.
    budget = (await db.execute(select(AdBudget).where(
        AdBudget.campaign_id == campaign.id))).scalar_one_or_none()
    spent = float(budget.spent) if budget else 0.0
    total = float(budget.total_budget) if budget else 0.0
    if campaign.status not in (AdCampaignStatus.active,
                               AdCampaignStatus.paused):
        run.status = OptimizationRunStatus.skipped
        run.summary = {"status": "skipped",
                       "reason": f"campaign is {campaign.status.value} — "
                                 "not deliverable, nothing to optimize"}
        run.ended_at = _now()
        await db.commit()
        return run.summary
    if total > 0 and spent >= total:
        run.status = OptimizationRunStatus.skipped
        run.summary = {"status": "skipped",
                       "reason": "budget exhausted — delivery already stopped",
                       "spent_usd": spent, "budget_usd": total}
        run.ended_at = _now()
        await db.commit()
        return run.summary

    seg_weights = await ensure_segment_weights(db, campaign)
    variants = await ensure_variants(db, campaign)
    placements = (await db.execute(select(AdPlacement).where(
        AdPlacement.campaign_id == campaign.id)
        .order_by(AdPlacement.weight.desc()))).scalars().all()

    metrics = await _measure(db, campaign.id)
    totals = metrics["totals"]
    free_cap = plans_svc.FREE_PLAN_MAX_IMPRESSIONS
    if is_free and totals["impressions"] >= free_cap:
        # The serve layer already stopped delivery at the cap; the agent
        # just records why there is nothing to optimize.
        run.status = OptimizationRunStatus.skipped
        run.summary = {
            "status": "skipped",
            "reason": ("Free Grow impression limit reached — delivery "
                       "already stopped"),
            "agent": agent,
            "impressions": totals["impressions"],
            "free_limit": free_cap}
        run.ended_at = _now()
        await db.commit()
        return run.summary
    # Free Grow AI winds down expansion as the free limit approaches: no
    # new variants, no weight increases — it says so honestly instead of
    # pushing growth it cannot deliver.
    wind_down = (is_free and totals["impressions"] >= int(
        free_cap * agents_svc.FREE_WIND_DOWN_FRACTION))
    decisions: list[str] = []
    segments_adjusted = 0
    placements_compared = len(placements)
    variants_tested = len([v for v in variants
                           if v.status == VariantStatus.active])

    # ---- safety first: suspicious traffic → auto-pause, never optimize on it
    fraud_reasons = _detect_suspicious(metrics, campaign.freq_cap or 3)
    if fraud_reasons:
        paused_placements: list[str] = []
        for p in placements:
            if p.status == PlacementStatus.active:
                p.status = PlacementStatus.paused
                paused_placements.append(str(p.id))
        campaign.status = AdCampaignStatus.paused
        await _decision(
            db, campaign, agent, "auto_paused_safety",
            ["Suspicious traffic detected — the campaign is PAUSED rather "
             "than optimized on fabricated events. An admin must review "
             "before delivery resumes."] + fraud_reasons,
            {"events_count": metrics["events_count"],
             "totals": totals,
             "paused_placements": paused_placements})
        run.status = OptimizationRunStatus.safety_paused
        run.summary = {"status": "safety_paused",
                       "fraud_reasons": fraud_reasons,
                       "paused_placements": paused_placements,
                       "events_count": metrics["events_count"]}
        run.ended_at = _now()
        await db.commit()
        return {"paused": True, "status": "safety_paused",
                "fraud_reasons": fraud_reasons, "run_id": str(run.id)}

    if wind_down:
        await _decision(
            db, campaign, agent, "approaching_free_limit",
            [f"Free Grow AI is winding down expansion: this campaign has "
             f"delivered {totals['impressions']} genuine impressions, "
             f"approaching the free limit of {free_cap}. No new variants "
             f"will be added and no segment weights will be increased — "
             f"the remaining delivery focuses on what already works. "
             f"Paid Boost has no impression cap."],
            {"agent": agent, "impressions": totals["impressions"],
             "free_limit": free_cap})
        decisions.append(
            "Approaching the Free Grow impression limit — expansion wound "
            "down.")

    # ---- segment weights: rules + bounded AI proposals
    by_segment = metrics["by_segment"]
    ai_proposal: dict | None = None
    ai_meta: dict = {"heuristic": True}
    try:
        ai_proposal = await propose_optimization_via_ai(
            _campaign_summary(campaign, totals),
            [{"id": str(r.segment_id), "name": "",
              **by_segment.get(str(r.segment_id), {})}
             for r in seg_weights],
            [{"id": str(p.id), "name": p.placement_type.value,
              **metrics["by_placement"].get(str(p.id), {})}
             for p in placements])
        if ai_proposal is not None:
            ai_meta = ai_source_meta()
    except Exception:  # never let the AI call break the optimizer
        ai_proposal = None
    ai_seg = {a["id"]: a for a in (ai_proposal or {}).get("segment_actions", [])}

    for row in seg_weights:
        sid = str(row.segment_id)
        m = by_segment.get(sid, {})
        imp = m.get("impressions", 0)
        rate = m.get("engagement_rate", 0.0)
        before = round(row.weight, 3)
        note: str
        if imp < MIN_IMPRESSIONS:
            note = (f"Insufficient data ({imp} impressions < "
                    f"{MIN_IMPRESSIONS} minimum) — weight kept at {before}. "
                    "No decision is made on tiny samples.")
            action = "keep_insufficient_data"
        elif imp >= MIN_IMPRESSIONS_PAUSE and rate <= PAUSE_RATE:
            row.weight = _clamp_weight(MIN_WEIGHT)
            note = (f"Very weak engagement ({rate:.2%} over {imp} "
                    f"impressions) — weight floored to {row.weight:.2f}.")
            action = "segment_weakened"
        elif rate <= WEAK_RATE:
            row.weight = _clamp_weight(row.weight * 0.6)
            note = (f"Weak engagement ({rate:.2%} over {imp} impressions) — "
                    f"weight {before:.2f} → {row.weight:.2f}.")
            action = "segment_weakened"
        elif rate >= STRONG_RATE:
            if wind_down:
                # Free Grow AI near the free limit: hold strong segments
                # steady instead of expanding into them.
                note = (f"Strong engagement ({rate:.2%} over {imp} "
                        f"impressions) — weight kept at {before:.2f} "
                        f"(winding down near the free limit, no expansion).")
                action = "segment_kept"
            else:
                row.weight = _clamp_weight(row.weight * 1.4)
                note = (f"Strong engagement ({rate:.2%} over {imp} impressions) "
                        f"— weight {before:.2f} → {row.weight:.2f}.")
                action = "segment_strengthened"
        else:
            note = (f"Average engagement ({rate:.2%} over {imp} impressions) "
                    f"— weight kept at {before:.2f}.")
            action = "segment_kept"

        # Bounded AI overlay: multiplier 0.5..1.5, never a pause on its own.
        ai_note = ""
        ai_act = ai_seg.get(sid)
        if ai_act and action != "keep_insufficient_data":
            mult = float(ai_act["multiplier"])
            if ai_act["action"] in ("up", "down") and mult != 1.0:
                row.weight = _clamp_weight(row.weight * mult)
                ai_note = (f" AI suggestion applied (×{mult:.2f}, within "
                           f"bounds): {ai_act['note']}")
            elif ai_act["action"] == "pause":
                ai_note = (" AI suggested pausing this segment, but pauses "
                           "require admin review — weight kept, flagged for "
                           "review.")

        # Snapshot the measured state onto the row (explainability).
        row.impressions = imp
        row.views = m.get("views", 0)
        row.engagements = m.get("engagements", 0)
        row.engagement_rate = rate

        await _decision(db, campaign, agent, action,
                        [note + ai_note,
                         f"Minimum-sample guard: {MIN_IMPRESSIONS} "
                         "impressions before any weight change."],
                        {"segment_id": sid, "ai_source": ai_meta,
                         "before": {"weight": before},
                         "after": {"weight": round(row.weight, 3)},
                         "metrics": m})
        if action not in ("keep_insufficient_data", "segment_kept"):
            segments_adjusted += 1
        decisions.append(note)

    # ---- geo-segment optimization: per-country reweighting from genuine
    # per-country signals (declared segment geography only — never viewer
    # location). Runs after the per-segment rules so both layers are
    # visible in the audit trail.
    geo_segments_adjusted = await _optimize_geo_segments(
        db, campaign, agent, seg_weights, by_segment, wind_down, decisions)

    # ---- variant weights: deterministic rotation follows performance
    active_vars = [v for v in variants if v.status == VariantStatus.active]
    var_counts = metrics["by_variant"]
    if active_vars:
        scores = []
        for v in active_vars:
            c = var_counts.get(str(v.id), {})
            imp = c.get("impressions", 0)
            # Laplace smoothing toward 0.5 so small samples can't swing wildly.
            s = (c.get("engagements", 0) + 0.5 * 5) / (imp + 5)
            scores.append(s)
        shares = _softmax(scores, TEMPERATURE)
        for v, sh in zip(active_vars, shares):
            before = round(v.weight, 3)
            v.weight = round(
                max(0.05, (1 - EXPLORE_FLOOR) * sh
                    + EXPLORE_FLOOR / len(active_vars)), 3)
            await _decision(
                db, campaign, agent, "variant_reweighted",
                [f"Variant '{v.label}': rotation share set to {v.weight} "
                 f"from smoothed engagement score {scores[active_vars.index(v)]:.3f}. "
                 f"{EXPLORE_FLOOR:.0%} always kept exploring."],
                {"variant_id": str(v.id), "ai_source": ai_meta,
                 "before": {"weight": before},
                 "after": {"weight": v.weight},
                 "metrics": var_counts.get(str(v.id), {})})
        decisions.append("Variant rotation shares updated from measured "
                         "performance.")

        # Stagnation → one honest new variant (heuristic or AI-proposed).
        new_spec = None
        ai_new = (ai_proposal or {}).get("new_variant")
        only_original = len(variants) == 1 and variants[0].is_original
        if only_original and totals["impressions"] >= MIN_IMPRESSIONS:
            if ai_new:
                new_spec = {
                    "label": ai_new["label"], "kind": "hook",
                    "content": {"hook": ai_new["hook"],
                               "caption": ai_new["caption"],
                               "hashtags": ai_new["hashtags"]},
                    "rationale": ai_new["rationale"] +
                    " (AI-proposed, bounded: starts at low weight).",
                }
            else:
                hv = _heuristic_variant(campaign)
                new_spec = hv
        if new_spec and len(variants) < 4 and not wind_down:
            nv = AdVariant(
                campaign_id=campaign.id, label=new_spec["label"],
                kind=new_spec["kind"], content=new_spec["content"],
                rationale=new_spec["rationale"], weight=0.1,
                status=VariantStatus.active, is_original=False)
            db.add(nv)
            variants.append(nv)
            variants_tested += 1
            await _decision(
                db, campaign, agent, "variant_added",
                [f"New variant '{new_spec['label']}' added at weight 0.1 — "
                 "only the original had been tested so far."],
                {"ai_source": ai_meta,
                 "metrics": {"impressions": totals["impressions"]}})
            decisions.append(
                f"New creative variant '{new_spec['label']}' added for testing.")

    # ---- placements: compare and shift weight toward better performers
    active_places = [p for p in placements
                     if p.status == PlacementStatus.active]
    by_place = metrics["by_placement"]
    ai_pl = {a["id"]: a for a in (ai_proposal or {}).get("placement_actions", [])}
    if active_places:
        scores = []
        for p in active_places:
            c = by_place.get(str(p.id), {})
            imp = c.get("impressions", 0)
            # Score: engagement rate with Laplace smoothing; tiny samples
            # stay near the prior so they can't swing the allocation.
            scores.append((c.get("engagements", 0) + 0.5 * 10) / (imp + 10))
        shares = _softmax(scores, TEMPERATURE)
        n = len(active_places)
        for p, sh in zip(active_places, shares):
            before = round(p.weight, 3)
            target = round(
                max(0.2, min(2.0, (1 - EXPLORE_FLOOR) * n * sh
                              + EXPLORE_FLOOR * 1.0)), 3)
            ai_act = ai_pl.get(str(p.id))
            if ai_act and ai_act["action"] in ("up", "down"):
                target = round(_clamp_weight(
                    target * float(ai_act["multiplier"])), 3)
            p.weight = target
            await _decision(
                db, campaign, agent, "placement_reweighted",
                [f"Placement '{p.placement_type.value}': weight "
                 f"{before:.2f} → {p.weight:.2f} from measured engagement "
                 f"score {scores[active_places.index(p)]:.3f}. "
                 f"{EXPLORE_FLOOR:.0%} always kept exploring."],
                {"placement_id": str(p.id), "ai_source": ai_meta,
                 "before": {"weight": before},
                 "after": {"weight": p.weight},
                 "metrics": by_place.get(str(p.id), {})})
        decisions.append("Placement weights shifted toward better-performing "
                         "placements.")

    # Budget can only stay the same or shrink — verify the invariant.
    budget_after = (await db.execute(select(AdBudget).where(
        AdBudget.campaign_id == campaign.id))).scalar_one_or_none()
    if budget_after is not None and \
            float(budget_after.spent) > float(budget_after.total_budget) + 1e-9:
        raise AssertionError("optimizer invariant violated: spend exceeded "
                             "the approved budget")

    run.status = OptimizationRunStatus.completed
    # Paid Boost AI reports cost-efficiency: genuine results per dollar of
    # the package budget. Free Grow AI has no spend, so this stays null.
    cost_efficiency = None
    _eng = totals.get("engagements", 0)
    _spent_now = float(budget_after.spent) if budget_after else 0.0
    _total_now = float(budget_after.total_budget) if budget_after else 0.0
    if not is_free and _spent_now > 0 and _eng > 0:
        cost_efficiency = {
            "spent_usd": round(_spent_now, 4),
            "engagements": _eng,
            "cost_per_engagement_usd": round(_spent_now / _eng, 4),
            "note": ("Measured cost per genuine engagement — an observed "
                     "figure, not a promise of future cost.")}
    run.summary = {
        "agent": agent,
        "geo": geo_svc.geo_context(campaign),
        "segments_adjusted": segments_adjusted,
        "geo_segments_adjusted": geo_segments_adjusted,
        "variants_tested": variants_tested,
        "placements_compared": placements_compared,
        "decisions": decisions,
        "ai_source": ai_meta,
        "totals": totals,
        "budget": {"spent_usd": round(_spent_now, 4),
                   "total_usd": round(_total_now, 4)},
        "cost_efficiency": cost_efficiency,
        "wound_down": wind_down,
        "window": "all measured genuine events",
        "min_sample_guard": MIN_IMPRESSIONS,
    }
    run.ended_at = _now()
    await _decision(
        db, campaign, agent, "run_completed",
        decisions or ["No structural changes — weights already reflect "
                      "measured performance."],
        {"ai_source": ai_meta, "run_id": str(run.id),
         "totals": totals, "budget": run.summary["budget"]})
    await db.commit()
    return {"run_id": str(run.id), "status": "completed",
            "agent": agent, "summary": run.summary}


def _campaign_summary(campaign: AdCampaign, totals: dict) -> str:
    return (
        f"objective={campaign.objective.value} "
        f"impressions={totals['impressions']} views={totals['views']} "
        f"engagements={totals['engagements']} "
        f"engagement_rate={totals['engagement_rate']} "
        f"topics={campaign.topics} languages={campaign.languages}")


# ------------------------------------------------------------------ insights
def _plain_segment_line(name: str, weight: float, m: dict) -> str:
    imp = m.get("impressions", 0)
    if imp < MIN_IMPRESSIONS:
        return (f"{name}: only {imp} impressions so far — too little data "
                f"to judge (the optimizer waits for {MIN_IMPRESSIONS}). "
                f"Weight stays at {weight:.2f}.")
    rate = m.get("engagement_rate", 0.0)
    verdict = ("performing well" if rate >= STRONG_RATE
               else "underperforming" if rate <= WEAK_RATE
               else "performing about average")
    return (f"{name}: {imp} impressions → {m.get('views', 0)} views, "
            f"{m.get('engagements', 0)} engagements "
            f"({rate:.1%} engagement rate) — {verdict}. "
            f"Current weight {weight:.2f}.")


async def campaign_insights(db: AsyncSession,
                            campaign_id: uuid.UUID) -> dict:
    """Explainable performance summary: per-segment, per-variant,
    per-placement — plain language + measured figures + disclaimers."""
    campaign = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == campaign_id))).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Ad campaign not found")
    metrics = await _measure(db, campaign.id)
    seg_weights = await ensure_segment_weights(db, campaign)
    variants = await ensure_variants(db, campaign)
    placements = (await db.execute(select(AdPlacement).where(
        AdPlacement.campaign_id == campaign.id))).scalars().all()
    seg_names = {str(s.id): s.name
                 for s in await _campaign_segments(db, campaign)}

    seg_lines = []
    for row in seg_weights:
        sid = str(row.segment_id)
        seg_lines.append({
            "segment_id": sid,
            "segment_name": seg_names.get(sid, "Unknown segment"),
            "weight": round(row.weight, 3),
            **metrics["by_segment"].get(sid, {}),
            "plain": _plain_segment_line(
                seg_names.get(sid, "Unknown segment"), row.weight,
                metrics["by_segment"].get(sid, {})),
        })
    var_lines = []
    for v in variants:
        c = metrics["by_variant"].get(str(v.id), {})
        var_lines.append({
            "variant_id": str(v.id), "label": v.label,
            "is_original": v.is_original, "status": v.status.value,
            "weight": round(v.weight, 3), **c,
            "plain": (f"Variant '{v.label}': {c.get('impressions', 0)} "
                      f"impressions, {c.get('engagement_rate', 0):.1%} "
                      f"engagement rate — rotation share {v.weight:.2f}."
                      if c.get("impressions") else
                      f"Variant '{v.label}': no measured events yet — "
                      f"rotation share {v.weight:.2f}."),
        })
    place_lines = []
    for p in placements:
        c = metrics["by_placement"].get(str(p.id), {})
        place_lines.append({
            "placement_id": str(p.id),
            "placement_type": p.placement_type.value,
            "status": p.status.value, "weight": round(p.weight, 3), **c,
            "plain": (f"{p.placement_type.value}: {c.get('impressions', 0)} "
                      f"impressions, {c.get('engagement_rate', 0):.1%} "
                      f"engagement rate — weight {p.weight:.2f}."
                      if c.get("impressions") else
                      f"{p.placement_type.value}: no measured events yet — "
                      f"weight {p.weight:.2f}."),
        })

    await db.commit()  # persist ensure_* rows
    geo_ctx = geo_svc.geo_context(campaign)
    by_country: dict[str, dict] = {}
    seg_geo = {str(s.id): str(getattr(s, "geography", "") or "").strip().upper()
               for s in await _campaign_segments(db, campaign)}
    for row in seg_weights:
        g = seg_geo.get(str(row.segment_id), "") or "GLOBAL"
        agg = by_country.setdefault(g, {"impressions": 0, "engagements": 0,
                                        "segments": 0})
        m = metrics["by_segment"].get(str(row.segment_id), {})
        agg["impressions"] += m.get("impressions", 0)
        agg["engagements"] += m.get("engagements", 0)
        agg["segments"] += 1
    country_lines = []
    for g in sorted(by_country):
        agg = by_country[g]
        imp = agg["impressions"]
        rate = (agg["engagements"] / imp) if imp else 0.0
        country_lines.append({
            "country": g,
            "country_name": ("Global (no declared geography)"
                             if g == "GLOBAL"
                             else geo_svc.COUNTRY_NAMES.get(g, g)),
            "segments": agg["segments"],
            "impressions": imp,
            "engagements": agg["engagements"],
            "engagement_rate": round(rate, 4),
            "plain": (
                f"{geo_svc.COUNTRY_NAMES.get(g, g) if g != 'GLOBAL' else 'Global'}: "
                f"{imp} genuine impressions across {agg['segments']} "
                f"segment(s), {rate:.1%} engagement rate — measured from "
                f"declared segment geography, never viewer location."
                if imp >= MIN_IMPRESSIONS else
                f"{geo_svc.COUNTRY_NAMES.get(g, g) if g != 'GLOBAL' else 'Global'}: "
                f"only {imp} impressions so far — too little data to judge "
                f"(minimum {MIN_IMPRESSIONS})."),
        })
    geo_ctx["by_country"] = country_lines
    return {
        "campaign_id": str(campaign.id),
        "growth_agent": agents_svc.agent_for_plan(campaign.plan),
        "geo": geo_ctx,
        "status": campaign.status.value,
        "objective": campaign.objective.value,
        "totals": metrics["totals"],
        "segments": seg_lines,
        "variants": var_lines,
        "placements": place_lines,
        "min_sample_guard": MIN_IMPRESSIONS,
        "note": ("Figures come from genuine measured events only — never "
                 "inflated. Segments below the minimum sample are not judged."),
        "disclaimer": DISCLAIMER,
    }


async def optimization_history(db: AsyncSession,
                               campaign_id: uuid.UUID) -> dict:
    """Run history + the optimizer's audit trail (explainable decisions)."""
    campaign = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == campaign_id))).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Ad campaign not found")
    runs = (await db.execute(select(AdOptimizationRun).where(
        AdOptimizationRun.campaign_id == campaign.id)
        .order_by(AdOptimizationRun.started_at.desc()).limit(50)
    )).scalars().all()
    decisions = (await db.execute(select(AdDecision).where(
        AdDecision.campaign_id == campaign.id,
        AdDecision.agent.in_(agents_svc.ALL_GROWTH_AGENTS))
        .order_by(AdDecision.created_at.desc()).limit(200)
    )).scalars().all()
    return {
        "campaign_id": str(campaign.id),
        "runs": [{
            "id": str(r.id), "status": r.status.value,
            "triggered_by": r.triggered_by,
            "started_at": r.started_at.isoformat() if r.started_at else None,
            "ended_at": r.ended_at.isoformat() if r.ended_at else None,
            "summary": r.summary,
        } for r in runs],
        "decisions": [{
            "id": str(d.id), "action": d.action,
            "details": d.details,
            "created_at": d.created_at.isoformat() if d.created_at else None,
        } for d in decisions],
        "disclaimer": DISCLAIMER,
    }


# ------------------------------------------------------------------ celery beat
@celery.task(name="virello.ads.optimize_tick")
def tick_ad_optimizations() -> dict:
    """Beat task: run the optimizer over active campaigns whose last run is
    older than OPTIMIZE_INTERVAL_HOURS (or never ran). Idempotent — a run
    only adjusts weights from newly measured events."""
    async def _go() -> dict:
        ran = []
        async for db in get_db():
            campaigns = (await db.execute(select(AdCampaign).where(
                AdCampaign.status == AdCampaignStatus.active)
            )).scalars().all()
            for c in campaigns:
                last = (await db.execute(select(AdOptimizationRun)
                    .where(AdOptimizationRun.campaign_id == c.id)
                    .order_by(AdOptimizationRun.started_at.desc()).limit(1)
                )).scalar_one_or_none()
                last_at = (last.ended_at or last.started_at) if last else None
                if last_at is not None:
                    age = (_now().replace(tzinfo=None)
                           - last_at.replace(tzinfo=None)).total_seconds() / 3600
                    if age < OPTIMIZE_INTERVAL_HOURS:
                        continue
                # Skip campaigns with no measured events — nothing to learn.
                n = (await db.execute(select(func.count())
                    .select_from(AdImpression)
                    .where(AdImpression.campaign_id == c.id))).scalar() or 0
                if not n:
                    continue
                try:
                    ran.append(await run_optimization(
                        db, c.id, triggered_by="scheduler"))
                except Exception as exc:  # one bad campaign never kills the tick
                    ran.append({"campaign_id": str(c.id),
                                "status": "failed", "error": str(exc)[:200]})
        return {"ran": ran, "count": len(ran)}
    return _await_sync(_go())


def _await_sync(coro):
    """Run a coroutine from sync Celery task code (mirrors growth_engine)."""
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    else:
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            return pool.submit(lambda: asyncio.run(coro)).result()
