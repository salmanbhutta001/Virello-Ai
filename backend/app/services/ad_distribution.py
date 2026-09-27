"""Ad Distribution — Sponsored Discovery serving, pacing, and measurement.

Serve logic (all genuine, all explainable):
1. Only campaigns with status=active and at least one active placement.
2. Budget guardrails: hard stop when spent >= total_budget; pacing spreads
   spend evenly across duration_days (daily_cap = total / duration_days —
   a campaign that already spent today's allowance is skipped, never
   overserved).
3. Segment eligibility: the campaign's content signals are scored against
   active audience segments (reusing audience_matching.score_segment), and the
   viewer's declared opt-in interests + language are checked against each
   segment's criteria. Membership is computed at match time — never stored.
4. Frequency caps: a user sees a given campaign at most freq_cap times
   (genuine impressions only, counted from ad_impressions).
5. Every served unit carries is_sponsored=True and a "Sponsored" label in
   the user's language. Organic results are never labeled, sponsored units
   are never presented as organic.

Pricing model (transparent, simulated accounting — NOT real money movement):
spend is derived only from priced genuine events recorded in ad_impressions:

    objective      priced events                 cost per event (USD)
    views          view                          0.01
    engagement     like | save | click           0.05
    followers      follow                        0.50
    leads          visit                         1.00
    sales          visit                         1.00   (proxy — no checkout
                                                        integration yet)

Impressions themselves are free (delivery is not charged); only the genuine
engagement that matches the campaign's objective accrues spend. Spend is
clamped so it can NEVER exceed the advertiser-approved total_budget.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ad_delivery import (
    AdBudget,
    AdEventType,
    AdImpression,
    AdPlacement,
    PlacementStatus,
    PlacementType,
)
from app.models.ads import (
    AdCampaign,
    AdCampaignStatus,
    AdDecision,
    AudienceSegment,
)
from app.services import audience_matching as match_svc
from app.services import geo as geo_svc
from app.services import plans as plans_svc

# ---------------------------------------------------------------- pricing

# Cost per priced event (USD), keyed by campaign objective. Impressions are
# free; only genuine engagement matching the objective accrues spend.
# Documented, fixed, and auditable — the delivery endpoint returns the exact
# priced-event counts so any spend figure can be re-derived by hand.
PRICING: dict[str, dict[str, float]] = {
    "views": {"view": 0.01},
    "engagement": {"like": 0.05, "save": 0.05, "click": 0.05},
    "followers": {"follow": 0.50},
    "leads": {"visit": 1.00},
    "sales": {"visit": 1.00},
}

PRICING_DISCLAIMER = (
    "Spend is simulated accounting derived from genuine measured events at "
    "the published per-event rates — not real money movement. Real charging "
    "requires a payment provider integration (PayPal / Payoneer / Google Pay).")

SPONSORED_LABEL = {"en": "Sponsored", "ur": "مشتہر"}

#: Duplicate event confirmations inside this window are rejected as
#: already-recorded (anti-abuse), never double-counted.
EVENT_DEDUPE_WINDOW = timedelta(hours=24)


def priced_cost(objective: str, event_type: str) -> float:
    """USD cost of one genuine event for the objective; 0.0 if not priced."""
    return float(PRICING.get(objective, {}).get(event_type, 0.0))


def daily_budget(total: float, duration_days: int) -> float:
    days = max(1, int(duration_days or 1))
    return round(float(total) / days, 4)


def _today_iso() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def _naive_now() -> datetime:
    # SQLite returns naive datetimes; compare naive-to-naive.
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _pacing(b: AdBudget) -> dict:
    """Reset the day's counter when the date rolled over (mutates + returns)."""
    state = dict(b.pacing_state or {})
    today = _today_iso()
    if state.get("date") != today:
        state = {"date": today, "spent_today": 0.0}
        b.pacing_state = state
    state.setdefault("spent_today", 0.0)
    return state


async def _decision(db: AsyncSession, campaign_id: uuid.UUID, agent: str,
                    action: str, reasons: list[str], metrics: dict,
                    geo: dict | None = None) -> None:
    details = {"reasons": reasons, "metrics": metrics,
               "disclaimer": PRICING_DISCLAIMER}
    if geo is not None:
        details["geo"] = geo
    db.add(AdDecision(
        campaign_id=campaign_id, agent=agent, action=action, details=details))


# ---------------------------------------------------------------- geo-aware delivery
# The AI agent engine delivers a campaign ONLY into its effective country
# set (geo.resolve_effective_countries). Country attribution always comes
# from a segment's DECLARED geography — per-user location is never
# inferred, never stored, never used.

def _safe_effective(campaign: AdCampaign) -> dict | None:
    """Effective geo for a campaign; None when the stored selection is
    corrupt (the campaign is then skipped — never served blind)."""
    try:
        return geo_svc.resolve_effective_countries(
            campaign.geo_mode, list(campaign.geo_countries or []),
            campaign.suggested_geography or {})
    except ValueError:
        return None


def plan_geo_allocation(effective: dict,
                        segments: list[AudienceSegment]) -> dict:
    """Per-country delivery allocation plan for the effective set.

    Target share is split equally across effective countries that have at
    least one eligible segment (declared geography in the set). Countries
    with no segment coverage get share 0 — reported honestly, since no
    delivery can be planned there from declared data. Global segments (no
    declared geography) are not country-bound; they serve under the overall
    plan, not a country share.
    """
    countries = ([] if effective.get("worldwide")
                 else list(effective.get("countries") or []))
    if not countries:
        return {"shares": {}, "uncovered": [], "worldwide": True,
                "note": "Worldwide delivery — no per-country allocation."}
    covered: dict[str, list[str]] = {}
    for s in segments:
        g = str(getattr(s, "geography", "") or "").strip().upper()
        if g and g in countries:
            covered.setdefault(g, []).append(str(s.id))
    eligible = [c for c in countries if c in covered]
    shares = ({c: round(1.0 / len(eligible), 4) for c in eligible}
              if eligible else {})
    uncovered = [c for c in countries if c not in covered]
    note = (f"Equal target share across {len(eligible)} covered "
            f"countr{'y' if len(eligible) == 1 else 'ies'}."
            if eligible else
            "No eligible segment covers any targeted country — delivery "
            "falls back to global segments only.")
    if uncovered:
        names = ", ".join(geo_svc.COUNTRY_NAMES.get(c, c)
                          for c in uncovered)
        note += f" No declared segment coverage for: {names}."
    return {"shares": shares, "uncovered": uncovered, "worldwide": False,
            "note": note}


async def _country_delivery(db: AsyncSession,
                            campaign_id: uuid.UUID) -> dict[str, int]:
    """Genuine impressions per declared segment geography for a campaign.

    Country attribution comes ONLY from the segment's declared geography —
    never from viewer data (which we do not collect for this purpose).
    """
    rows = (await db.execute(
        select(AudienceSegment.geography, func.count())
        .select_from(AdImpression)
        .join(AudienceSegment,
              AdImpression.segment_id == AudienceSegment.id)
        .where(AdImpression.campaign_id == campaign_id,
               AdImpression.event_type == AdEventType.impression)
        .group_by(AudienceSegment.geography))).all()
    return {(g or "").strip().upper(): int(n) for g, n in rows}


def _pick_geo_candidate(candidates: list[dict], shares: dict[str, float],
                        delivered: dict[str, int]) -> dict:
    """Choose the served segment: best content match wins, but among
    near-tied candidates (within 0.05) the country furthest behind its
    target share is preferred — so delivery spreads across the targeted
    countries instead of piling into one. Explainable via geo_reason."""
    if not candidates:
        raise ValueError("no candidates")
    if not shares:
        best = max(candidates, key=lambda c: c["score"])
        best["geo_reason"] = ("No per-country allocation (worldwide or no "
                              "covered countries) — best content match "
                              "served.")
        return best
    total = sum(delivered.get(c, 0) for c in shares) or 1
    best_score = max(c["score"] for c in candidates)

    def _deficit(c: dict) -> float:
        g = c["segment_geography"]
        if not g or g not in shares:
            return 0.0  # global segments: no country deficit
        return shares[g] - delivered.get(g, 0) / total

    near = [c for c in candidates if best_score - c["score"] <= 0.05]
    pick = max(near, key=_deficit)
    g = pick["segment_geography"]
    if g and g in shares:
        pick["geo_reason"] = (
            f"{geo_svc.COUNTRY_NAMES.get(g, g)} is behind its target share "
            f"({shares[g]:.0%} target vs "
            f"{delivered.get(g, 0) / total:.0%} delivered) — preferred so "
            f"delivery spreads across the targeted countries.")
    else:
        pick["geo_reason"] = ("Best content match served (global segment — "
                              "not bound to one country).")
    return pick


async def _country_spend_today(db: AsyncSession,
                               campaign: AdCampaign) -> dict[str, float]:
    """Today's priced-event spend grouped by declared segment geography.

    Only priced event types for the campaign objective count (the same
    priced_cost accounting as the budget). Segments without a declared
    geography are not country-attributed.
    """
    priced = set(PRICING.get(campaign.objective.value, {}))
    if not priced:
        return {}
    ets = [AdEventType(t) for t in priced]
    start = _naive_now().replace(hour=0, minute=0, second=0, microsecond=0)
    rows = (await db.execute(
        select(AudienceSegment.geography, AdImpression.event_type)
        .select_from(AdImpression)
        .join(AudienceSegment,
              AdImpression.segment_id == AudienceSegment.id)
        .where(AdImpression.campaign_id == campaign.id,
               AdImpression.event_type.in_(ets),
               AdImpression.occurred_at >= start))).all()
    spend: dict[str, float] = {}
    for g, et in rows:
        geo = str(g or "").strip().upper()
        if not geo:
            continue
        spend[geo] = round(
            spend.get(geo, 0.0)
            + priced_cost(campaign.objective.value, et.value), 4)
    return spend


# ---------------------------------------------------------------- eligibility

async def _active_segments(db: AsyncSession,
                           segment_ids: list[str] | None) -> list[AudienceSegment]:
    """Advertiser-chosen segments if set (and still active), else all active."""
    from app.services import audience_intelligence as ai_svc
    all_active = await ai_svc.list_active_segments(db)
    if not segment_ids:
        return all_active
    wanted = {s for s in segment_ids}
    return [s for s in all_active if str(s.id) in wanted]


def _user_fit(segment: AudienceSegment, interests: set[str],
              language: str) -> tuple[bool, list[str]]:
    """Does the viewer (declared interests + language) fit this segment?

    Only opt-in/declared signals are used: the user's chosen topics and their
    app language. Returns (eligible, reasons)."""
    reasons: list[str] = []
    seg_topics = {t.strip().lower() for t in (segment.topics or [])}
    if seg_topics:
        overlap = sorted(seg_topics & interests)
        if not overlap:
            return False, [f"Viewer has no opted-in topics in {segment.name}"]
        reasons.append(
            f"Viewer opted into {', '.join(overlap[:3])} — matches {segment.name}")
    else:
        reasons.append(f"{segment.name} has no topic criteria — open to all")
    seg_langs = [str(l).strip().lower() for l in (segment.languages or [])]
    if seg_langs and language and language not in seg_langs:
        return False, [f"Viewer language ({language}) not in segment languages"]
    if seg_langs:
        reasons.append(f"Viewer language fits {segment.name}")
    return True, reasons


async def _impression_count(db: AsyncSession, campaign_id: uuid.UUID,
                            user_id: uuid.UUID) -> int:
    row = (await db.execute(
        select(func.count()).select_from(AdImpression).where(
            AdImpression.campaign_id == campaign_id,
            AdImpression.viewer_user_id == user_id,
            AdImpression.event_type == AdEventType.impression))).scalar()
    return int(row or 0)


async def _campaign_impression_total(db: AsyncSession,
                                     campaign_id: uuid.UUID) -> int:
    """Genuine impressions across ALL viewers — the Free Grow cap unit."""
    row = (await db.execute(
        select(func.count()).select_from(AdImpression).where(
            AdImpression.campaign_id == campaign_id,
            AdImpression.event_type == AdEventType.impression))).scalar()
    return int(row or 0)


async def _get_budget(db: AsyncSession, campaign_id: uuid.UUID) -> AdBudget | None:
    return (await db.execute(select(AdBudget).where(
        AdBudget.campaign_id == campaign_id))).scalar_one_or_none()


# ---------------------------------------------------------------- serving

async def _pick_variant_for(db: AsyncSession, campaign,
                            user) -> dict | None:
    """Phase 3: deterministic weighted rotation over the campaign's creative
    variants, so the rotation the optimizer tunes is what viewers actually
    get. Returns None when no variants exist (launch creates the baseline)."""
    from app.models.ad_optimization import AdVariant
    from app.services import ad_optimizer as opt
    rows = (await db.execute(select(AdVariant).where(
        AdVariant.campaign_id == campaign.id))).scalars().all()
    v = opt.pick_variant(rows, user.id, campaign.id)
    if v is None:
        return None
    return {"variant_id": str(v.id), "label": v.label,
            "content": v.content, "is_original": v.is_original}

async def serve_ads(db: AsyncSession, user, limit: int = 2) -> list[dict]:
    """Return eligible sponsored units for the viewer.

    Every unit carries ``is_sponsored=True`` and a "Sponsored" label — this
    is non-negotiable and asserted in tests. Units the viewer already hit
    their frequency cap on, campaigns out of budget / over daily pacing, and
    paused placements are never returned."""
    from app.services.discovery.service import get_my_interests
    interests = set(await get_my_interests(db, user.id))
    language = (user.locale or "en").strip().lower()
    label = SPONSORED_LABEL.get(language, SPONSORED_LABEL["en"])

    rows = (await db.execute(select(AdCampaign).where(
        AdCampaign.status == AdCampaignStatus.active))).scalars().all()

    units: list[dict] = []
    for campaign in rows:
        budget = await _get_budget(db, campaign.id)
        if budget is None:
            continue
        # Geo-aware engine: resolve the effective country set first. A
        # campaign with a corrupt stored selection is never served blind.
        effective = _safe_effective(campaign)
        if effective is None:
            continue
        eff_set = (set(effective["countries"])
                   if not effective["worldwide"] else None)
        geo_summary = geo_svc.geo_targeting_summary(
            effective["mode"], effective["countries"])
        # Free Grow campaigns never spend: no budget hard-stop, no pacing.
        # They deliver organically (worldwide); spend stays 0 forever.
        # LIMITED: a free campaign auto-completes after
        # FREE_PLAN_MAX_IMPRESSIONS genuine impressions.
        is_free = campaign.plan == "free"
        if is_free:
            delivered = await _campaign_impression_total(db, campaign.id)
            if delivered >= plans_svc.FREE_PLAN_MAX_IMPRESSIONS:
                campaign.status = AdCampaignStatus.completed
                await _decision(
                    db, campaign.id, "system", "free_limit_reached",
                    ["Free Grow limit reached — the campaign delivered "
                     f"{delivered} genuine impressions (free limit: "
                     f"{plans_svc.FREE_PLAN_MAX_IMPRESSIONS}) and was "
                     "completed automatically. Paid Boost has no "
                     "impression cap."],
                    {"impressions": delivered,
                     "free_limit": plans_svc.FREE_PLAN_MAX_IMPRESSIONS},
                    geo=geo_svc.geo_context(campaign))
                continue
        if not is_free:
            # Hard stop: never exceed the approved budget.
            if float(budget.spent) >= float(budget.total_budget):
                continue
            # Pacing: spread delivery across duration_days.
            state = _pacing(budget)
            if float(state.get("spent_today", 0.0)) >= float(budget.daily_cap):
                continue
        # Frequency cap: genuine impressions only.
        seen = await _impression_count(db, campaign.id, user.id)
        if seen >= int(campaign.freq_cap or 0):
            continue

        placements = (await db.execute(
            select(AdPlacement)
            .where(AdPlacement.campaign_id == campaign.id,
                   AdPlacement.status == PlacementStatus.active)
            .order_by(AdPlacement.weight.desc()))).scalars().all()
        if not placements:
            continue

        segments = await _active_segments(db, campaign.segment_ids)
        signals = campaign.content_signals or {}
        candidates: list[dict] = []
        geo_excluded: list[str] = []
        for seg in segments:
            # Geo gate: only segments whose declared geography is inside
            # the campaign's effective country set may deliver.
            fit = match_svc.geography_fit(seg, eff_set)
            if not fit["in_target"]:
                geo_excluded.append(fit["reason"])
                continue
            content_match = match_svc.score_segment(signals, seg)
            if content_match["score"] < match_svc.DEFAULT_THRESHOLD:
                continue
            fits, user_reasons = _user_fit(seg, interests, language)
            if not fits:
                continue
            candidates.append({
                "segment": seg, "score": content_match["score"],
                "segment_geography": fit["segment_geography"],
                "reasons": ((content_match["reasons"] or []) + user_reasons
                            + [fit["reason"]]),
            })
        if not candidates:
            continue

        # Per-country allocation: prefer the targeted country furthest
        # behind its share (declared segment geography only).
        allocation = plan_geo_allocation(effective, segments)
        delivered_by_country = await _country_delivery(db, campaign.id)
        ordered = sorted(
            candidates,
            key=lambda c: (c["score"],),
            reverse=True)
        # rank by the geo-aware pick: try in preference order so the
        # per-country pacing check below can fall through to the next.
        best_first = _pick_geo_candidate(
            candidates, allocation["shares"], delivered_by_country)
        ordered = [best_first] + [c for c in ordered
                                  if c["segment"] is not best_first["segment"]]

        # Per-country pacing (paid, geo-targeted only): the daily cap is
        # split across covered countries; a country that already spent its
        # share is skipped for country-declared segments. Global segments
        # fall back to the overall daily cap (already checked above).
        country_spend: dict[str, float] = {}
        country_cap = 0.0
        shares = allocation["shares"]
        if not is_free and shares:
            country_spend = await _country_spend_today(db, campaign)
            country_cap = round(float(budget.daily_cap) / len(shares), 4)

        best: dict | None = None
        for cand in ordered:
            g = cand["segment_geography"]
            if shares and g and g in shares:
                if country_spend.get(g, 0.0) >= country_cap:
                    continue  # this country's daily share is spent
            best = cand
            break
        if best is None:
            continue

        placement = placements[0]
        seg = best["segment"]
        # Phase 3: deterministic weighted variant rotation — the client
        # confirms which variant actually rendered via variant_id on events.
        variant = await _pick_variant_for(db, campaign, user)
        units.append({
            "campaign_id": str(campaign.id),
            "placement_id": str(placement.id),
            "placement_type": placement.placement_type.value,
            "segment_id": str(seg.id),
            "segment_name": seg.name,
            "match_score": best["score"],
            "match_reasons": best["reasons"][:4],
            "objective": campaign.objective.value,
            "content_ref": (campaign.content_ref or "")[:500],
            "topics": campaign.topics or [],
            "variant": variant,
            # ---- transparency: never presented as organic, always labeled
            "is_sponsored": True,
            "label": label,
            "geo_targeting": geo_summary,  # e.g. "Targeting: Pakistan, UAE"
            "geo_reason": best.get("geo_reason", ""),
            "sponsored_note": (
                "Sponsored — this placement is paid advertising and is "
                "clearly labeled. Delivery and spend are measured from "
                "genuine events only."),
        })
        if len(units) >= max(1, limit):
            break

    await db.commit()  # persist any pacing-day rollovers
    return units


# ---------------------------------------------------------------- events

def _validate_event_type(event_type: str) -> AdEventType:
    try:
        return AdEventType(event_type)
    except ValueError:
        raise ValueError(
            f"event_type must be one of {[e.value for e in AdEventType]}")


async def record_ad_event(db: AsyncSession, *, campaign_id: uuid.UUID,
                          placement_id: uuid.UUID | None,
                          segment_id: uuid.UUID | None,
                          user_id: uuid.UUID, event_type: str,
                          meta: dict | None = None,
                          variant_id: uuid.UUID | None = None) -> dict:
    """Record ONE genuine delivery event.

    Validation rejects: unknown event types, events for campaigns that are
    not deliverable (draft/pending/rejected/completed), placements or
    segments that do not belong to the campaign, and duplicate confirmations
    inside the dedupe window (returned as recorded=False, never
    double-counted).

    Priced events (genuine engagement matching the campaign objective)
    accrue spend, clamped so total spend can NEVER exceed the approved
    budget. When the budget is exhausted the campaign is marked completed.
    """
    et = _validate_event_type(event_type)
    campaign = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == campaign_id))).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Ad campaign not found")
    if campaign.status not in (AdCampaignStatus.active, AdCampaignStatus.paused):
        raise ValueError(
            f"Events are only recorded for deliverable campaigns "
            f"(active/paused); this one is {campaign.status.value}.")

    placement = None
    if placement_id is not None:
        placement = (await db.execute(select(AdPlacement).where(
            AdPlacement.id == placement_id,
            AdPlacement.campaign_id == campaign_id))).scalar_one_or_none()
        if placement is None:
            raise ValueError("Placement does not belong to this campaign.")

    segment = None
    if segment_id is not None:
        segment = (await db.execute(select(AudienceSegment).where(
            AudienceSegment.id == segment_id))).scalar_one_or_none()
        if segment is None:
            raise ValueError("Segment not found.")

    # Phase 3: per-variant attribution — the variant must belong to the campaign.
    if variant_id is not None:
        from app.models.ad_optimization import AdVariant
        variant = (await db.execute(select(AdVariant).where(
            AdVariant.id == variant_id,
            AdVariant.campaign_id == campaign_id))).scalar_one_or_none()
        if variant is None:
            raise ValueError("Variant does not belong to this campaign.")

    # Anti-abuse dedupe: one event per (campaign, user, placement, type)
    # per window. Genuine re-engagement after the window is still recorded.
    since = _naive_now() - EVENT_DEDUPE_WINDOW
    dup = (await db.execute(select(AdImpression.id).where(
        AdImpression.campaign_id == campaign_id,
        AdImpression.viewer_user_id == user_id,
        AdImpression.placement_id == placement_id,
        AdImpression.event_type == et,
        AdImpression.occurred_at >= since))).scalar_one_or_none()
    if dup is not None:
        return {"recorded": False, "event_type": et.value,
                "note": "already recorded within the dedupe window"}

    budget = await _get_budget(db, campaign_id)
    cost = 0.0
    # Spend accrues only while the campaign is actively delivering, and only
    # for genuine priced engagement. Free Grow campaigns never accrue spend
    # (cost forced to 0) — their delivery is organic, not billed.
    if budget is not None and campaign.status == AdCampaignStatus.active:
        if campaign.plan == "free":
            cost = 0.0
        else:
            cost = priced_cost(campaign.objective.value, et.value)
        if cost > 0:
            new_spent = min(float(budget.spent) + cost,
                            float(budget.total_budget))
            state = _pacing(budget)
            state["spent_today"] = round(
                float(state.get("spent_today", 0.0)) + cost, 4)
            budget.pacing_state = state
            budget.spent = round(new_spent, 4)
            if float(budget.spent) >= float(budget.total_budget):
                campaign.status = AdCampaignStatus.completed
                await _decision(
                    db, campaign.id, "system", "budget_exhausted",
                    ["Approved budget fully spent — delivery stopped and the "
                     "campaign marked completed. Spend never exceeds the "
                     "advertiser-approved budget."],
                    {"spent": budget.spent,
                     "total_budget": budget.total_budget},
                    geo=geo_svc.geo_context(campaign))

    db.add(AdImpression(
        campaign_id=campaign_id, placement_id=placement_id,
        segment_id=segment_id, variant_id=variant_id,
        viewer_user_id=user_id,
        event_type=et, meta=dict(meta or {})))
    await db.commit()
    spent = float(budget.spent) if budget else 0.0
    total = float(budget.total_budget) if budget else 0.0
    return {
        "recorded": True, "event_type": et.value,
        "cost_usd": round(cost, 4),
        "spent_usd": spent, "budget_usd": total,
        "disclaimer": PRICING_DISCLAIMER,
    }


# ---------------------------------------------------------------- delivery stats

async def delivery_stats(db: AsyncSession, campaign_id: uuid.UUID) -> dict:
    """Owner/admin delivery overview: genuine measured events, spend derived
    from priced events, pacing status, per-placement breakdown."""
    campaign = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == campaign_id))).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Ad campaign not found")
    budget = await _get_budget(db, campaign_id)
    state = _pacing(budget) if budget else {"date": _today_iso(),
                                           "spent_today": 0.0}

    rows = (await db.execute(select(AdImpression).where(
        AdImpression.campaign_id == campaign_id))).scalars().all()
    by_type: dict[str, int] = {e.value: 0 for e in AdEventType}
    priced_events = 0
    for r in rows:
        by_type[r.event_type.value] = by_type.get(r.event_type.value, 0) + 1
        if priced_cost(campaign.objective.value, r.event_type.value) > 0:
            priced_events += 1

    placements = (await db.execute(select(AdPlacement).where(
        AdPlacement.campaign_id == campaign_id))).scalars().all()
    breakdown = []
    for p in placements:
        counts = {e.value: 0 for e in AdEventType}
        for r in rows:
            if r.placement_id == p.id:
                counts[r.event_type.value] += 1
        breakdown.append({
            "placement_id": str(p.id),
            "placement_type": p.placement_type.value,
            "status": p.status.value, "weight": p.weight,
            "events": counts,
            "impressions": counts["impression"],
        })

    spent = float(budget.spent) if budget else 0.0
    total = float(budget.total_budget) if budget else 0.0
    return {
        "campaign_id": str(campaign_id),
        "status": campaign.status.value,
        "objective": campaign.objective.value,
        "impressions": by_type["impression"],
        "events": by_type,
        "priced_events": priced_events,
        "spent_usd": round(spent, 4),
        "budget_usd": total,
        "remaining_usd": round(max(0.0, total - spent), 4),
        "pacing": {
            "daily_cap_usd": float(budget.daily_cap) if budget else 0.0,
            "spent_today_usd": round(float(state.get("spent_today", 0.0)), 4),
            "date": state.get("date"),
            "on_pace": (float(state.get("spent_today", 0.0))
                        < float(budget.daily_cap)) if budget else False,
        },
        "placements": breakdown,
        "freq_cap": campaign.freq_cap,
        "pricing": PRICING.get(campaign.objective.value, {}),
        "note": ("Counts reflect genuine measured events only — never "
                 "inflated."),
        "disclaimer": PRICING_DISCLAIMER,
    }
