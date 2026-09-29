"""AI Advertising Platform API (Phase 1) — owner-scoped.

Builder flow: paste post/link → AI analysis + proposals → draft campaign.
NOTHING launches without explicit advertiser approval:
  draft → PATCH(status=pending_approval) → approve → approved.
``active`` is NOT reachable through the public API in Phase 1 — the approval
gate is enforced, and any attempt to set it directly returns 400.
All estimates carry an "estimate — not a guarantee" disclaimer.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.ad_delivery import AdBudget, AdPlacement, PlacementStatus, PlacementType
from app.models.ads import AdCampaign, AdCampaignStatus, AdDecision, AdObjective
from app.models.core import User
from app.services import (
    ad_attribution as attr_svc,
    ad_distribution as dist,
    ad_optimizer as opt_svc,
    audience_intelligence as ai_svc,
    audience_matching as match_svc,
    campaign_builder as builder,
    geo as geo_svc,
    growth_agents as agents_svc,
    plans as plans_svc,
)
from app.services import language as lang_svc

router = APIRouter()


def _campaign_json(c: AdCampaign) -> dict:
    return {
        "id": str(c.id), "objective": c.objective.value,
        "content_ref": c.content_ref[:500],
        "content_signals": c.content_signals,
        "topics": c.topics, "languages": c.languages,
        "language_targeting_mode": c.language_targeting_mode,
        "target_languages": c.target_languages,
        "suggested_languages": c.suggested_languages,
        "segment_ids": c.segment_ids, "budget": c.budget,
        "duration_days": c.duration_days,
        "plan": c.plan,  # free | paid — Free Grow vs Paid Boost
        "package_id": c.package_id,  # paid package label, null for free
        "growth_agent": agents_svc.agent_for_plan(c.plan),
        # free_growth_agent | paid_growth_agent — the AI managing this campaign
        "geo_mode": c.geo_mode,
        "geo_countries": c.geo_countries,
        "suggested_geography": c.suggested_geography,
        # Geo-aware engine: what the AI agents actually target, in one
        # place — mode, effective countries, and a display line like
        # "Targeting: Pakistan, UAE +3 more" (EN + UR).
        "geo_targeting": geo_svc.geo_context(c),
        "freq_cap": c.freq_cap,  # Phase 2: max genuine impressions per user
        "status": c.status.value,
        "estimate": c.estimate,
        "ai_provider": c.ai_provider, "ai_model": c.ai_model,
        "dev": c.dev,
        "created_at": c.created_at.isoformat() if c.created_at else None,
        "updated_at": c.updated_at.isoformat() if c.updated_at else None,
    }


async def _owned(db: AsyncSession, user: User, campaign_id: str) -> AdCampaign:
    c = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == uuid.UUID(campaign_id)))).scalar_one_or_none()
    if c is None or c.owner_id != user.id:
        raise HTTPException(404, "Ad campaign not found")
    return c


class BuildIn(BaseModel):
    url: str | None = None
    content: str | None = None
    budget_cap: float | None = None
    objective_hint: str | None = None
    geo_mode: str | None = None  # ai_recommended|worldwide|custom
    geo_countries: list[str] | None = None  # ISO codes, for custom
    plan: str | None = None  # free|paid — Free Grow vs Paid Boost
    package_id: str | None = None  # paid only: starter|growth|pro|scale


@router.get("/packages")
async def packages(user: User = Depends(get_current_user)) -> dict:
    """Free plan limits + Paid Boost packages for the plan picker UI."""
    return plans_svc.packages_payload()


@router.get("/agents")
async def agents(user: User = Depends(get_current_user)) -> dict:
    """The two growth AI agents: Free Grow AI vs Paid Boost AI."""
    return agents_svc.agents_payload()


@router.get("/geo/countries")
async def geo_countries(db: AsyncSession = Depends(get_db),
                        user: User = Depends(get_current_user)) -> dict:
    """Country picker data: full ISO country list + region presets."""
    return builder.geo_svc.countries_payload()


@router.post("/campaigns", status_code=201)
async def build(body: BuildIn, db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    """AI Campaign Builder: analyze content → propose → save as DRAFT."""
    try:
        result = await builder.build_campaign(
            db, user, url=body.url, content=body.content,
            budget_cap=body.budget_cap, objective_hint=body.objective_hint,
            geo_mode=body.geo_mode, geo_countries=body.geo_countries,
            plan=body.plan, package_id=body.package_id)
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    return {
        "campaign": _campaign_json(result["campaign"]),
        "analysis": {
            "signals": result["signals"],
            "disclaimer": ("Content analysis is a heuristic assessment, "
                           "not a prediction of performance."),
        },
        "matches": result["matches"],
        "proposal": result["proposal"],
        "estimate": result["estimate"],
        "used_ai": result["used_ai"],
        "suggested_geography": result["campaign"].suggested_geography,
    }


@router.get("/campaigns")
async def list_mine(db: AsyncSession = Depends(get_db),
                    user: User = Depends(get_current_user),
                    plan: str | None = None) -> dict:
    """Owner's campaigns, newest first. Optional ?plan=free|paid filter so
    the app can show Free and Paid modules separately."""
    q = select(AdCampaign).where(AdCampaign.owner_id == user.id)
    if plan is not None:
        p = plan.strip().lower()
        if p not in ("free", "paid"):
            raise HTTPException(400, "plan filter must be 'free' or 'paid'.")
        q = q.where(AdCampaign.plan == p)
    rows = (await db.execute(q.order_by(
        AdCampaign.created_at.desc()))).scalars().all()
    return {"campaigns": [_campaign_json(c) for c in rows]}


@router.get("/campaigns/{campaign_id}")
async def detail(campaign_id: str, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    c = await _owned(db, user, campaign_id)
    segments = await ai_svc.list_active_segments(db)
    # Matches shown here respect the campaign's geography: segments whose
    # declared geography is outside the effective country set are excluded
    # (worldwide campaigns filter nothing).
    geo = geo_svc.geo_context(c)
    matches = await match_svc.match_segments(
        db, c.content_signals or {}, segments,
        geo_countries=(None if geo["geo_worldwide"]
                       else geo["geo_countries"]))
    decisions = (await db.execute(select(AdDecision).where(
        AdDecision.campaign_id == c.id).order_by(
            AdDecision.created_at.desc()).limit(50))).scalars().all()
    return {
        "campaign": _campaign_json(c),
        "matches": matches,
        "decisions": [{
            "id": str(d.id), "agent": d.agent, "action": d.action,
            "details": d.details,
            "created_at": d.created_at.isoformat() if d.created_at else None}
            for d in decisions],
    }


class PatchIn(BaseModel):
    objective: str | None = None
    budget: float | None = None
    duration_days: int | None = None
    topics: list[str] | None = None
    languages: list[str] | None = None
    language_targeting_mode: str | None = None  # single|multiple|all_relevant
    target_languages: list[str] | None = None
    segment_ids: list[str] | None = None
    geo_mode: str | None = None  # ai_recommended|worldwide|custom
    geo_countries: list[str] | None = None  # ISO codes, for custom
    plan: str | None = None  # immutable — rejected if it differs
    package_id: str | None = None  # paid only: switch package (sets budget+duration)
    status: str | None = None  # only draft -> pending_approval is allowed


_EDITABLE = {AdCampaignStatus.draft, AdCampaignStatus.pending_approval}


@router.patch("/campaigns/{campaign_id}")
async def edit(campaign_id: str, body: PatchIn,
               db: AsyncSession = Depends(get_db),
               user: User = Depends(get_current_user)) -> dict:
    c = await _owned(db, user, campaign_id)
    if c.status not in _EDITABLE:
        raise HTTPException(400, f"Cannot edit a campaign in status {c.status.value}.")

    # Plan is chosen at creation and can never change: a Free Grow campaign
    # cannot become a Paid Boost (or vice versa) — create a new campaign.
    if body.plan is not None and body.plan.strip().lower() != c.plan:
        raise HTTPException(
            400, "A campaign's plan cannot be changed after creation. "
                 "Create a new campaign for the other plan.")
    if c.plan == "free":
        # Free Grow contract: no budget, worldwide only. Loud rejections so
        # clients never silently drift a free campaign into paid semantics.
        if body.budget is not None:
            raise HTTPException(
                400, "Free campaigns have no budget — it stays $0.")
        if body.geo_mode is not None:
            raise HTTPException(
                400, "Free campaigns are worldwide-only — geography cannot "
                     "be changed.")
        if body.geo_countries is not None:
            raise HTTPException(
                400, "Free campaigns are worldwide-only — geography cannot "
                     "be changed.")
        if body.package_id is not None:
            raise HTTPException(
                400, "Free campaigns don't use packages — choose Paid Boost.")

    if body.objective is not None:
        try:
            c.objective = AdObjective(body.objective)
        except ValueError:
            raise HTTPException(400, "Invalid objective.")
    if body.budget is not None:
        if body.budget < 0 or body.budget > 10000:
            raise HTTPException(400, "budget must be 0..10000.")
        if body.package_id is not None:
            raise HTTPException(
                400, "Use either package_id or budget, not both.")
        c.budget = body.budget
    if body.package_id is not None:
        # Paid Boost: switching package resets budget AND duration to the
        # package's fixed values — no manual budgeting.
        package = plans_svc.get_package(body.package_id)
        if package is None:
            raise HTTPException(
                400, f"Unknown package '{body.package_id}'. Choose from "
                     f"{[p['id'] for p in plans_svc.PAID_PACKAGES]}.")
        c.package_id = package["id"]
        c.budget = float(package["price_usd"])
        c.duration_days = int(package["duration_days"])
    if body.duration_days is not None:
        if not 1 <= body.duration_days <= 90:
            raise HTTPException(400, "duration_days must be 1..90.")
        c.duration_days = body.duration_days
    if body.topics is not None:
        c.topics = [t.strip().lower() for t in body.topics][:8]
    if body.languages is not None:
        c.languages = [str(l).strip().lower() for l in body.languages][:4]
    if body.language_targeting_mode is not None:
        mode = body.language_targeting_mode.strip().lower()
        if mode not in ("single", "multiple", "all_relevant"):
            raise HTTPException(
                400, "language_targeting_mode must be single, multiple, "
                     "or all_relevant.")
        c.language_targeting_mode = mode
    if body.target_languages is not None:
        langs = [str(l).strip().lower() for l in body.target_languages][:8]
        for code in langs:
            if not lang_svc.is_supported(code):
                raise HTTPException(400, f"Unsupported language: {code}.")
        c.target_languages = langs
    if body.segment_ids is not None:
        c.segment_ids = [str(s) for s in body.segment_ids][:5]
    if body.geo_mode is not None:
        try:
            c.geo_mode = builder.geo_svc.validate_geo_mode(body.geo_mode)
        except ValueError as exc:
            raise HTTPException(400, str(exc))
    if body.geo_countries is not None:
        try:
            c.geo_countries = builder.geo_svc.validate_countries(
                body.geo_countries)
        except ValueError as exc:
            raise HTTPException(400, str(exc))
        if c.geo_mode != "custom":
            # Explicit country list implies the advertiser takes control.
            c.geo_mode = "custom"
    if c.geo_mode == "custom" and not c.geo_countries:
        raise HTTPException(
            400, "custom geography needs at least one country.")

    if body.status is not None:
        # Approval gate: the ONLY status change an owner can make here is
        # submitting the draft for approval. ``active`` (and everything
        # else) is unreachable — it always returns 400.
        if body.status == "pending_approval" and c.status == AdCampaignStatus.draft:
            c.status = AdCampaignStatus.pending_approval
            db.add(AdDecision(campaign_id=c.id, agent="builder",
                              action="submit_for_approval",
                              details={"reasons": ["Advertiser submitted the "
                                                   "draft for approval."],
                                       "metrics": {},
                                       "disclaimer": builder.ESTIMATE_DISCLAIMER}))
        else:
            raise HTTPException(
                400, "Only draft → pending_approval is allowed here. "
                     "Approval happens via the approve endpoint.")
    # Keep the reach estimate honest: recompute from the CURRENT settings
    # (budget/duration/objective/segments/geography) after every draft edit.
    c.estimate = await builder.recompute_estimate(db, c)
    await db.commit()
    await db.refresh(c)
    return {"campaign": _campaign_json(c)}


@router.post("/campaigns/{campaign_id}/approve")
async def approve(campaign_id: str, db: AsyncSession = Depends(get_db),
                  user: User = Depends(get_current_user)) -> dict:
    """Advertiser approval gate: pending_approval → approved."""
    c = await _owned(db, user, campaign_id)
    if c.status != AdCampaignStatus.pending_approval:
        raise HTTPException(
            400, "Only a campaign pending approval can be approved.")
    c.status = AdCampaignStatus.approved
    db.add(AdDecision(campaign_id=c.id, agent="builder", action="approved",
                      details={"reasons": ["Advertiser explicitly approved "
                                           "the campaign. Nothing launches "
                                           "without this approval."],
                               "metrics": {"budget": c.budget,
                                           "duration_days": c.duration_days},
                               "disclaimer": builder.ESTIMATE_DISCLAIMER}))
    await db.commit()
    await db.refresh(c)
    return {"campaign": _campaign_json(c)}


@router.post("/campaigns/{campaign_id}/reject")
async def reject(campaign_id: str, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    c = await _owned(db, user, campaign_id)
    if c.status not in (AdCampaignStatus.draft,
                        AdCampaignStatus.pending_approval):
        raise HTTPException(400, "Only draft/pending campaigns can be rejected.")
    c.status = AdCampaignStatus.rejected
    db.add(AdDecision(campaign_id=c.id, agent="builder", action="rejected",
                      details={"reasons": ["Advertiser rejected the campaign."],
                               "metrics": {},
                               "disclaimer": builder.ESTIMATE_DISCLAIMER}))
    await db.commit()
    await db.refresh(c)
    return {"campaign": _campaign_json(c)}


# ---------------------------------------------------------------- Phase 2:
# Sponsored Discovery — launch / pause / resume / serve / events / delivery

class LaunchIn(BaseModel):
    placement_types: list[str] = ["sponsored_discovery"]
    freq_cap: int | None = None  # max genuine impressions per user


def _placement_json(p: AdPlacement) -> dict:
    return {
        "id": str(p.id), "campaign_id": str(p.campaign_id),
        "placement_type": p.placement_type.value,
        "status": p.status.value, "weight": p.weight,
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }


@router.post("/campaigns/{campaign_id}/launch")
async def launch(campaign_id: str, body: LaunchIn,
                 db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    """Owner launch: approved → active. Creates the ad placements and the
    budget/pacing row. Nothing serves before this explicit launch."""
    c = await _owned(db, user, campaign_id)
    if c.status != AdCampaignStatus.approved:
        raise HTTPException(
            400, "Only an approved campaign can be launched.")
    if c.plan == "paid" and c.budget <= 0:
        raise HTTPException(400, "Set a positive budget before launching.")
    # Free Grow launches with budget 0 by design: no spend ever accrues,
    # delivery is organic discovery (worldwide). The AdBudget row below is
    # still created (zeros) so pacing/spend code paths stay uniform; the
    # serve/charge guards skip budget checks for free campaigns.

    types: list[PlacementType] = []
    for t in body.placement_types or ["sponsored_discovery"]:
        try:
            types.append(PlacementType(t))
        except ValueError:
            raise HTTPException(
                400, f"Invalid placement_type '{t}'; choose from "
                     f"{[e.value for e in PlacementType]}.")
    if body.freq_cap is not None:
        if not 1 <= body.freq_cap <= 50:
            raise HTTPException(400, "freq_cap must be 1..50.")
        c.freq_cap = body.freq_cap

    c.status = AdCampaignStatus.active
    placements = []
    for i, t in enumerate(types):
        p = AdPlacement(campaign_id=c.id, placement_type=t,
                        status=PlacementStatus.active,
                        weight=1.0 - (i * 0.1))
        db.add(p)
        placements.append(p)
    db.add(AdBudget(
        campaign_id=c.id, total_budget=float(c.budget), spent=0.0,
        daily_cap=dist.daily_budget(c.budget, c.duration_days),
        pacing_state={"date": dist._today_iso(), "spent_today": 0.0}))
    # Phase 3: the advertiser's original is always the baseline creative
    # variant that rotation (and the optimizer) measures everything against.
    await opt_svc.ensure_variants(db, c)
    db.add(AdDecision(campaign_id=c.id, agent="system", action="launched",
                      details={
                          "reasons": [
                              "Advertiser launched the approved campaign — "
                              "the explicit step that makes it deliverable."],
                          "metrics": {
                              "budget": c.budget,
                              "daily_cap": dist.daily_budget(
                                  c.budget, c.duration_days),
                              "placements": [t.value for t in types],
                              "freq_cap": c.freq_cap},
                          "disclaimer": dist.PRICING_DISCLAIMER}))
    await db.commit()
    for p in placements:
        await db.refresh(p)
    await db.refresh(c)
    return {"campaign": _campaign_json(c),
            "placements": [_placement_json(p) for p in placements]}


@router.post("/campaigns/{campaign_id}/pause")
async def pause(campaign_id: str, db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    """Owner pause: active → paused. Paused campaigns are never served."""
    c = await _owned(db, user, campaign_id)
    if c.status != AdCampaignStatus.active:
        raise HTTPException(400, "Only an active campaign can be paused.")
    c.status = AdCampaignStatus.paused
    rows = (await db.execute(select(AdPlacement).where(
        AdPlacement.campaign_id == c.id))).scalars().all()
    for p in rows:
        p.status = PlacementStatus.paused
    db.add(AdDecision(campaign_id=c.id, agent="system", action="paused",
                      details={"reasons": ["Advertiser paused delivery."],
                               "metrics": {},
                               "disclaimer": dist.PRICING_DISCLAIMER}))
    await db.commit()
    await db.refresh(c)
    return {"campaign": _campaign_json(c)}


@router.post("/campaigns/{campaign_id}/resume")
async def resume(campaign_id: str, db: AsyncSession = Depends(get_db),
                 user: User = Depends(get_current_user)) -> dict:
    """Owner resume: paused → active. Refused (auto-completed) when the
    approved budget is already fully spent."""
    c = await _owned(db, user, campaign_id)
    if c.status != AdCampaignStatus.paused:
        raise HTTPException(400, "Only a paused campaign can be resumed.")
    budget = await dist._get_budget(db, c.id)
    spent = float(budget.spent) if budget else 0.0
    total = float(budget.total_budget) if budget else float(c.budget)
    # Free Grow campaigns never spend: the exhausted-budget guard does not
    # apply (their budget row is zeros by design).
    if c.plan != "free" and spent >= total:
        c.status = AdCampaignStatus.completed
        db.add(AdDecision(
            campaign_id=c.id, agent="system", action="resume_refused_completed",
            details={"reasons": [
                "Resume refused: the approved budget is fully spent. "
                "The campaign is marked completed."],
                "metrics": {"spent": spent, "total_budget": total},
                "disclaimer": dist.PRICING_DISCLAIMER}))
        await db.commit()
        await db.refresh(c)
        return {"campaign": _campaign_json(c),
                "note": "Budget fully spent — campaign completed."}
    c.status = AdCampaignStatus.active
    rows = (await db.execute(select(AdPlacement).where(
        AdPlacement.campaign_id == c.id))).scalars().all()
    for p in rows:
        p.status = PlacementStatus.active
    db.add(AdDecision(campaign_id=c.id, agent="system", action="resumed",
                      details={"reasons": ["Advertiser resumed delivery."],
                               "metrics": {"spent": spent, "total_budget": total},
                               "disclaimer": dist.PRICING_DISCLAIMER}))
    await db.commit()
    await db.refresh(c)
    return {"campaign": _campaign_json(c)}


@router.delete("/campaigns/{campaign_id}")
async def delete_campaign(campaign_id: str, db: AsyncSession = Depends(get_db),
                          user: User = Depends(get_current_user)) -> dict:
    """Owner delete: permanently removes the campaign and its placements,
    budgets, and decision log. Only the owning advertiser can delete."""
    c = await _owned(db, user, campaign_id)
    # Clean up related rows first.
    for model, col in ((AdPlacement, AdPlacement.campaign_id),
                       (AdDecision, AdDecision.campaign_id),
                       (AdBudget, AdBudget.campaign_id)):
        rows = (await db.execute(select(model).where(col == c.id))).scalars().all()
        for r in rows:
            await db.delete(r)
    await db.delete(c)
    await db.commit()
    return {"deleted": True, "campaign_id": campaign_id}


@router.get("/serve")
async def serve(limit: int = 2, db: AsyncSession = Depends(get_db),
                user: User = Depends(get_current_user)) -> dict:
    """Eligible sponsored units for the caller. Every unit carries
    is_sponsored=true and a "Sponsored" label — never presented as organic."""
    units = await dist.serve_ads(db, user, limit=min(max(limit, 1), 20))
    return {"units": units, "count": len(units),
            "disclaimer": ("Sponsored placements — paid advertising, clearly "
                           "labeled. Delivery is measured from genuine "
                           "events only.")}


class AdEventIn(BaseModel):
    campaign_id: str
    placement_id: str | None = None
    segment_id: str | None = None
    variant_id: str | None = None  # Phase 3: which creative variant rendered
    event_type: str  # impression | view | like | save | visit | follow | click
    meta: dict = {}


@router.post("/events", status_code=201)
async def record_event(body: AdEventIn, db: AsyncSession = Depends(get_db),
                       user: User = Depends(get_current_user)) -> dict:
    """Record ONE genuine delivery event. The client confirms what actually
    happened on the user's screen — a serve response alone is never counted.
    Unknown event types, non-deliverable campaigns, foreign placements, and
    duplicate confirmations inside the dedupe window are rejected."""
    try:
        result = await dist.record_ad_event(
            db,
            campaign_id=uuid.UUID(body.campaign_id),
            placement_id=uuid.UUID(body.placement_id)
            if body.placement_id else None,
            segment_id=uuid.UUID(body.segment_id)
            if body.segment_id else None,
            variant_id=uuid.UUID(body.variant_id)
            if body.variant_id else None,
            user_id=user.id,
            event_type=body.event_type,
            meta=body.meta or {})
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    # Phase 4: a genuine click mints an opaque click id so later landing
    # events can be attributed back. Clients append it to landing URLs as
    # ?virello_click_id=<token>. The token is opaque (no user id, no private
    # data) and expires after CLICK_ID_TTL.
    if result.get("recorded") and result.get("event_type") == "click":
        click_id = await attr_svc.mint_click_id(
            db,
            campaign_id=uuid.UUID(body.campaign_id),
            placement_id=uuid.UUID(body.placement_id)
            if body.placement_id else None,
            segment_id=uuid.UUID(body.segment_id)
            if body.segment_id else None,
            variant_id=uuid.UUID(body.variant_id)
            if body.variant_id else None)
        result["click_id"] = click_id
        result["click_id_note"] = (
            "Append to landing URLs as ?virello_click_id=<token> so the "
            "advertiser's pixel/webhook can report landing events against it.")
    return result


@router.get("/campaigns/{campaign_id}/delivery")
async def delivery(campaign_id: str, db: AsyncSession = Depends(get_db),
                   user: User = Depends(get_current_user)) -> dict:
    """Owner delivery overview: genuine measured events, spend derived from
    priced events, pacing status, per-placement breakdown."""
    c = await _owned(db, user, campaign_id)
    try:
        stats = await dist.delivery_stats(db, c.id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))
    return stats

# ---------------------------------------------------------------- Phase 3: AI Distribution & Optimization Agent

@router.post("/campaigns/{campaign_id}/optimize")
async def optimize_now(campaign_id: str, db: AsyncSession = Depends(get_db),
                       user: User = Depends(get_current_user)) -> dict:
    """Owner: run the AI Optimization Agent over this campaign right now.

    Aggregates genuine measured events per segment/variant/placement,
    reweights distribution within the approved budget, and audits every
    decision. Suspicious traffic auto-pauses instead of being optimized on.
    Only deliverable campaigns (active/paused) can be optimized."""
    c = await _owned(db, user, campaign_id)
    if c.status not in (AdCampaignStatus.active, AdCampaignStatus.paused):
        raise HTTPException(
            400, "Only active or paused campaigns can be optimized.")
    try:
        result = await opt_svc.run_optimization(db, c.id, triggered_by="manual")
    except ValueError as exc:
        raise HTTPException(404, str(exc))
    return result


@router.get("/campaigns/{campaign_id}/optimizations")
async def optimizations(campaign_id: str, db: AsyncSession = Depends(get_db),
                        user: User = Depends(get_current_user)) -> dict:
    """Owner: optimization run history + the optimizer's explainable audit
    trail (every decision with reasons and before/after metrics)."""
    c = await _owned(db, user, campaign_id)
    try:
        return await opt_svc.optimization_history(db, c.id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))


@router.get("/campaigns/{campaign_id}/insights")
async def insights(campaign_id: str, db: AsyncSession = Depends(get_db),
                   user: User = Depends(get_current_user)) -> dict:
    """Owner: per-segment / per-variant / per-placement performance summary
    in plain language. Figures come from genuine measured events only;
    everything is labeled as measured data, never a guaranteed outcome."""
    c = await _owned(db, user, campaign_id)
    try:
        return await opt_svc.campaign_insights(db, c.id)
    except ValueError as exc:
        raise HTTPException(404, str(exc))


# ---------------------------------------------------------------- Phase 4: Conversion Attribution

class LandingEventIn(BaseModel):
    click_id: str
    event_type: str  # page_view | lead | purchase | signup | custom
    value: float | None = None  # revenue for purchases (advertiser-reported)
    currency: str = "USD"
    source: str = "pixel"  # pixel | webhook | api
    meta: dict = {}


@router.post("/landing-event", status_code=201)
async def landing_event(body: LandingEventIn,
                        db: AsyncSession = Depends(get_db)) -> dict:
    """Pixel / webhook / API endpoint for advertiser-reported landing events.

    Deliberately NOT authenticated as a user: the caller's authority is the
    opaque click id (minted server-side on a genuine tap). The click id is
    validated (unknown or expired tokens are rejected), the endpoint is
    rate-limited per click id, and events are idempotent on
    (click_id, event_type) so a double-fired pixel never double-counts.

    Security note for production: this dev-grade gate (token check +
    in-memory limiter) must be replaced with SIGNED pixel tokens (HMAC of
    the click id) and a Redis-backed rate limiter.
    """
    try:
        return await attr_svc.record_landing_event(
            db, click_id=body.click_id, event_type=body.event_type,
            value=body.value, currency=body.currency, source=body.source,
            meta=body.meta or {})
    except ValueError as exc:
        raise HTTPException(400, str(exc))


@router.get("/campaigns/{campaign_id}/attribution")
async def attribution(campaign_id: str, db: AsyncSession = Depends(get_db),
                      user: User = Depends(get_current_user)) -> dict:
    """Owner: conversion attribution for this campaign — per-segment /
    per-variant conversions and advertiser-reported revenue under the
    last-click model (labeled as such; multi-touch is future work)."""
    c = await _owned(db, user, campaign_id)
    return await attr_svc.attribution_stats(db, c.id)


@router.get("/campaigns/{campaign_id}/dashboard")
async def dashboard(campaign_id: str, db: AsyncSession = Depends(get_db),
                    user: User = Depends(get_current_user)) -> dict:
    """Owner: ONE advertiser dashboard payload — spend, impressions, reach
    (honestly defined: distinct measurable viewers), views, engagement
    (likes+saves), followers gained, clicks, leads, conversions,
    cost_per_result, and attributable revenue. Every figure is labeled
    measured vs estimate; the pricing-model disclaimer is included."""
    c = await _owned(db, user, campaign_id)
    return await attr_svc.advertiser_dashboard(db, c.id)
