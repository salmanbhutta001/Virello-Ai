"""Conversion Attribution — future-ready conversion tracking.

How it works:
1. A user taps an ad → ``/ads/events`` (event_type=click) mints an OPAQUE
   click id (random token, never sequential) mapped to the ad's
   campaign/placement/segment/variant chain. The client appends it to the
   landing URL as ``?virello_click_id=<token>``.
2. The advertiser's integration (tracking pixel / server webhook / direct
   API call) reports landing-funnel events (page_view | lead | purchase |
   signup | custom) against that click id.
3. Conversion-type events are attributed LAST-CLICK to the click id's
   chain. Every attribution writes an AdDecision audit row
   (agent="attribution") with reasons.

Privacy: click ids carry NO user id and NO private user data. Advertisers
only ever see aggregate conversion counts and advertiser-reported revenue;
they never learn who clicked.

Honesty:
- ``value`` on landing events is ADVERTISER-REPORTED/measured revenue. The
  platform records what the advertiser's integration reports — it does not
  verify that a sale happened. Everywhere it appears it is labeled
  "advertiser-reported / measured", never "verified sales".
- Last-click is the only implemented model; multi-touch is documented as
  future work, and ``attributed_model`` is a plain string so it can land
  without a schema change.

Fraud guards:
- Values must be >= 0 and <= MAX_CONVERSION_VALUE_USD (absurd amounts are
  rejected — documented cap, not a secret one).
- Landing events are capped per click id (MAX_LANDING_EVENTS_PER_CLICK) —
  a runaway pixel cannot flood the pipeline.
- Landing events are idempotent on (click_id, event_type): a double-fired
  pixel records once, never double-counted.
- The public pixel/webhook endpoint is additionally rate-limited per
  click_id in memory (see _check_pixel_rate_limit); production MUST use a
  Redis-backed limiter and signed pixel tokens.
"""
from __future__ import annotations

import secrets
import time
import uuid
from collections import deque
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ad_attribution import (
    AdClickId,
    AdConversion,
    AdLandingEvent,
    LandingEventSource,
    LandingEventType,
)
from app.models.ads import AdDecision

#: Click tokens are usable for 30 days after minting; expired tokens are
#: rejected by record_landing_event.
CLICK_ID_TTL = timedelta(days=30)

#: Documented per-event value cap (USD). Events above this are rejected as
#: absurd — a fraud/abuse guard. Raised deliberately, never silently.
MAX_CONVERSION_VALUE_USD = 1_000_000.0

#: A single click id can carry at most this many landing events. A runaway
#: or replayed pixel cannot flood the pipeline.
MAX_LANDING_EVENTS_PER_CLICK = 200

#: Landing-funnel events that count as conversions (everything else —
#: page_view — is a landing signal only).
CONVERSION_EVENT_TYPES = frozenset({"lead", "purchase", "signup", "custom"})

#: The attribution model implemented today. Multi-touch is future work.
ATTRIBUTION_MODEL = "last_click"

REVENUE_DISCLAIMER = (
    "Revenue figures are advertiser-reported / measured from the "
    "advertiser's pixel, webhook, or API integration — not platform-verified "
    "sales.")

PIXEL_SECURITY_NOTE = (
    "Production must use signed pixel tokens (HMAC of the click id) and a "
    "Redis-backed rate limiter; the current token check + in-memory limiter "
    "is a dev-grade gate.")

#: Public pixel/webhook rate limit: max requests per click_id per minute.
#: In-memory — dev-grade only. Production MUST use a distributed limiter.
PIXEL_RATE_LIMIT_PER_MIN = 60
_PIXEL_HITS: dict[str, deque] = {}


def _naive_now() -> datetime:
    # SQLite returns naive datetimes; compare naive-to-naive.
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _check_pixel_rate_limit(click_id: str) -> None:
    """Sliding-window rate limit on the public landing-event endpoint."""
    now = time.monotonic()
    hits = _PIXEL_HITS.get(click_id)
    if hits is None:
        hits = _PIXEL_HITS[click_id] = deque()
    while hits and now - hits[0] > 60:
        hits.popleft()
    if len(hits) >= PIXEL_RATE_LIMIT_PER_MIN:
        raise ValueError(
            "Rate limit exceeded for this click id — try again shortly.")
    hits.append(now)


def _validate_event_type(event_type: str) -> LandingEventType:
    try:
        return LandingEventType(event_type)
    except ValueError:
        raise ValueError(
            f"event_type must be one of "
            f"{[e.value for e in LandingEventType]}")


def _validate_source(source: str) -> LandingEventSource:
    try:
        return LandingEventSource(source)
    except ValueError:
        raise ValueError(
            f"source must be one of "
            f"{[s.value for s in LandingEventSource]}")


def _validate_value(value: float | None) -> float | None:
    """Fraud guard: values must be sane. Negative or absurd amounts are
    rejected — never silently clamped, because silent clamping would hide
    advertiser fraud in the aggregates."""
    if value is None:
        return None
    try:
        v = float(value)
    except (TypeError, ValueError):
        raise ValueError("value must be a number or omitted")
    if v < 0:
        raise ValueError(
            f"value must be >= 0 (got {v}) — negative revenue is rejected.")
    if v > MAX_CONVERSION_VALUE_USD:
        raise ValueError(
            f"value {v} exceeds the per-event cap of "
            f"{MAX_CONVERSION_VALUE_USD:,.0f} USD — rejected as absurd. "
            f"(If this is legitimate, the cap must be raised deliberately.)")
    return v


# ---------------------------------------------------------------- minting

async def mint_click_id(
    db: AsyncSession, *, campaign_id: uuid.UUID,
    placement_id: uuid.UUID | None = None,
    segment_id: uuid.UUID | None = None,
    variant_id: uuid.UUID | None = None,
) -> str:
    """Mint an opaque click token for a tap on an ad unit. The token is a
    random 32-hex string; it maps the tap to its delivery chain so later
    landing events can be attributed back — with no user id involved."""
    token = secrets.token_hex(16)
    db.add(AdClickId(
        id=token, campaign_id=campaign_id,
        placement_id=placement_id, segment_id=segment_id,
        variant_id=variant_id,
        expires_at=_naive_now() + CLICK_ID_TTL))
    await db.commit()
    return token


# ---------------------------------------------------------------- landing events

async def _get_click(db: AsyncSession, click_id: str) -> AdClickId:
    click = (await db.execute(select(AdClickId).where(
        AdClickId.id == click_id))).scalar_one_or_none()
    if click is None:
        raise ValueError("Unknown click id — event rejected.")
    if click.expires_at is not None and click.expires_at <= _naive_now():
        raise ValueError("This click id has expired — event rejected.")
    return click


async def record_landing_event(
    db: AsyncSession, *, click_id: str, event_type: str,
    value: float | None = None, currency: str = "USD",
    source: str = "pixel", meta: dict | None = None,
) -> dict:
    """Record one advertiser-reported landing event against a click id.

    Validation rejects: unknown/expired click ids, unknown event types or
    sources, negative or absurd values, and click ids that already hit the
    per-click event cap. (click_id, event_type) is idempotent — a
    double-fired pixel returns recorded=False, never double-counted.

    Conversion-type events (lead/purchase/signup/custom) are immediately
    attributed last-click and audited.
    """
    _check_pixel_rate_limit(click_id)
    et = _validate_event_type(event_type)
    src = _validate_source(source)
    v = _validate_value(value)
    click = await _get_click(db, click_id)

    existing = (await db.execute(select(AdLandingEvent).where(
        AdLandingEvent.click_id == click_id,
        AdLandingEvent.event_type == et))).scalar_one_or_none()
    if existing is not None:
        return {"recorded": False, "event_type": et.value,
                "note": "already recorded for this click id — "
                        "double-submits are not double-counted"}

    count = (await db.execute(select(func.count()).select_from(
        AdLandingEvent).where(
            AdLandingEvent.click_id == click_id))).scalar() or 0
    if count >= MAX_LANDING_EVENTS_PER_CLICK:
        raise ValueError(
            f"This click id already has {count} landing events — cap "
            f"({MAX_LANDING_EVENTS_PER_CLICK}) reached; event rejected.")

    event = AdLandingEvent(
        click_id=click_id, event_type=et, value=v,
        currency=(currency or "USD")[:8].upper(),
        meta=dict(meta or {}), source=src)
    db.add(event)
    await db.flush()  # need the event id for attribution bookkeeping

    conversion: dict | None = None
    if et.value in CONVERSION_EVENT_TYPES:
        conv = await attribute(db, event, click)
        conversion = {"id": str(conv.id), "event_type": conv.event_type,
                      "attributed_model": conv.attributed_model}
    await db.commit()
    return {
        "recorded": True, "event_type": et.value,
        "click_id": click_id, "campaign_id": str(click.campaign_id),
        "conversion": conversion,
        "disclaimer": REVENUE_DISCLAIMER,
    }


# ---------------------------------------------------------------- attribution

async def attribute(db: AsyncSession, event: AdLandingEvent,
                    click: AdClickId) -> AdConversion:
    """Last-click attribution: the conversion belongs to the campaign /
    segment / variant of its click id. Multi-touch models are future work —
    this is documented, not hidden, in the audit row and API labels.

    Every attribution writes an AdDecision audit row (agent="attribution")
    with the chain and reasons, mirroring the ad platform's nothing-is-a-
    black-box contract."""
    conv = AdConversion(
        campaign_id=click.campaign_id, click_id=click.id,
        segment_id=click.segment_id, variant_id=click.variant_id,
        event_type=event.event_type.value, value=event.value,
        attributed_model=ATTRIBUTION_MODEL)
    db.add(conv)
    db.add(AdDecision(
        campaign_id=click.campaign_id, agent="attribution",
        action="attributed_last_click",
        details={
            "reasons": [
                f"Conversion (landing event {event.event_type.value}) "
                f"attributed to the campaign/segment/variant of its click "
                f"id under the last-click model.",
                "Multi-touch models are future work — last-click is the "
                "only implemented model and is labeled as such everywhere.",
            ],
            "metrics": {
                "conversion_id": str(conv.id),
                "click_id": click.id,
                "event_type": event.event_type.value,
                "value": event.value,
                "currency": event.currency,
                "segment_id": str(click.segment_id)
                if click.segment_id else None,
                "variant_id": str(click.variant_id)
                if click.variant_id else None,
                "source": event.source.value,
            },
            "disclaimer": REVENUE_DISCLAIMER,
        }))
    await db.flush()
    return conv


# ---------------------------------------------------------------- stats

async def attribution_stats(db: AsyncSession,
                            campaign_id: uuid.UUID) -> dict:
    """Owner-facing conversion attribution: per-segment / per-variant
    conversions and advertiser-reported revenue, labeled with the
    last-click model. Revenue is summed from advertiser-reported values —
    labeled as such, never as verified sales."""
    from app.models.ad_optimization import AdVariant
    from app.models.ads import AudienceSegment

    conversions = (await db.execute(select(AdConversion).where(
        AdConversion.campaign_id == campaign_id).order_by(
            AdConversion.occurred_at))).scalars().all()

    async def _name(model, _id: uuid.UUID | None) -> str | None:
        if _id is None:
            return None
        row = (await db.execute(select(model).where(
            model.id == _id))).scalar_one_or_none()
        return getattr(row, "name", None) or getattr(row, "label", None)

    by_segment: dict[str, dict] = {}
    by_variant: dict[str, dict] = {}
    total_value = 0.0
    for c in conversions:
        v = float(c.value) if c.value is not None else 0.0
        total_value += v
        if c.segment_id is not None:
            key = str(c.segment_id)
            slot = by_segment.setdefault(
                key, {"segment_id": key, "segment_name": None,
                      "conversions": 0, "revenue_usd": 0.0})
            slot["conversions"] += 1
            slot["revenue_usd"] = round(slot["revenue_usd"] + v, 2)
        if c.variant_id is not None:
            key = str(c.variant_id)
            slot = by_variant.setdefault(
                key, {"variant_id": key, "variant_label": None,
                      "conversions": 0, "revenue_usd": 0.0})
            slot["conversions"] += 1
            slot["revenue_usd"] = round(slot["revenue_usd"] + v, 2)
    for key, slot in by_segment.items():
        slot["segment_name"] = await _name(
            AudienceSegment, uuid.UUID(key)) or "Unknown segment"
    for key, slot in by_variant.items():
        slot["variant_label"] = await _name(
            AdVariant, uuid.UUID(key)) or "Unknown variant"

    by_type: dict[str, int] = {}
    for c in conversions:
        by_type[c.event_type] = by_type.get(c.event_type, 0) + 1

    return {
        "campaign_id": str(campaign_id),
        "attribution_model": ATTRIBUTION_MODEL,
        "model_label": ("last-click: each conversion is attributed to the "
                        "ad tap (campaign / segment / variant) that "
                        "preceded it. Multi-touch attribution is future "
                        "work."),
        "conversions": len(conversions),
        "attributable_revenue_usd": round(total_value, 2),
        "by_type": by_type,
        "by_segment": list(by_segment.values()),
        "by_variant": list(by_variant.values()),
        "note": ("Conversion counts and revenue are measured from genuine "
                 "recorded landing events."),
        "disclaimer": REVENUE_DISCLAIMER,
    }


async def advertiser_dashboard(db: AsyncSession,
                               campaign_id: uuid.UUID) -> dict:
    """ONE advertiser dashboard payload for a campaign: spend, delivery,
    engagement, clicks, leads, conversions, cost per result, and
    attributable revenue. Every figure is labeled measured vs estimate;
    the pricing-model disclaimer is included. Aggregates are derived from
    recorded genuine events only — the test suite asserts they match the
    recorded events exactly."""
    from app.models.ad_delivery import AdEventType, AdImpression
    from app.services import ad_distribution as dist

    delivery = await dist.delivery_stats(db, campaign_id)
    attribution = await attribution_stats(db, campaign_id)

    rows = (await db.execute(select(AdImpression).where(
        AdImpression.campaign_id == campaign_id))).scalars().all()
    viewers = {r.viewer_user_id for r in rows
               if r.event_type == AdEventType.impression
               and r.viewer_user_id is not None}
    # Genuine-event language breakdown: only events whose creative
    # language was genuinely recorded; the rest are "unrecorded",
    # never guessed.
    by_language: dict[str, int] = {}
    for r in rows:
        key = (r.language or "").strip().lower() or "unrecorded"
        by_language[key] = by_language.get(key, 0) + 1
    events = delivery["events"]
    views = events.get("view", 0)
    engagement = events.get("like", 0) + events.get("save", 0)
    followers = events.get("follow", 0)
    clicks = events.get("click", 0) + events.get("visit", 0)
    leads = attribution["by_type"].get("lead", 0) + \
        attribution["by_type"].get("signup", 0)
    conversions = attribution["conversions"]
    revenue = attribution["attributable_revenue_usd"]

    spent = delivery["spent_usd"]
    # Primary result for cost-per-result: conversions for leads/sales
    # objectives (the objective is conversion-shaped), otherwise the priced
    # genuine events the spend is actually derived from. Labeled estimate.
    if delivery["objective"] in ("leads", "sales"):
        primary_results = conversions
        cpr_basis = "conversions"
    else:
        primary_results = delivery["priced_events"]
        cpr_basis = "priced engagement events"
    cost_per_result = (round(spent / primary_results, 4)
                       if primary_results > 0 else None)

    def measured(value, note: str = "") -> dict:
        d = {"value": value, "kind": "measured"}
        if note:
            d["note"] = note
        return d

    return {
        "campaign_id": str(campaign_id),
        "status": delivery["status"],
        "objective": delivery["objective"],
        "metrics": {
            "spend_usd": measured(
                spent, "Simulated accounting from priced genuine events — "
                       "not real money movement."),
            "budget_usd": measured(delivery["budget_usd"]),
            "remaining_usd": measured(delivery["remaining_usd"]),
            "impressions": measured(
                delivery["impressions"],
                "Genuine renders confirmed by the client; a serve response "
                "alone is never counted."),
            "reach": measured(
                len(viewers),
                "Defined honestly: distinct viewers with a measurable "
                "identity who genuinely rendered the unit. Anonymous "
                "renders are excluded."),
            "views": measured(views, "Genuine opens / lingers."),
            "engagement": measured(
                engagement, "Genuine likes + saves."),
            "followers_gained": measured(
                followers, "Genuine follow events from the ad unit."),
            "clicks": measured(
                clicks, "Genuine taps (click + visit events). Each tap mints "
                        "an opaque click id for attribution."),
            "leads": measured(
                leads, "Lead + signup landing events attributed to this "
                       "campaign."),
            "conversions": measured(
                conversions,
                f"Last-click attributed conversions "
                f"({attribution['attribution_model']})."),
            "cost_per_result_usd": {
                "value": cost_per_result, "kind": "estimate",
                "note": f"Derived: spend / {cpr_basis}. An estimate — "
                        f"never a guaranteed outcome."},
            "attributable_revenue_usd": measured(
                revenue, REVENUE_DISCLAIMER),
        },
        "attribution_model": attribution["attribution_model"],
        "attribution_label": attribution["model_label"],
        "by_segment": attribution["by_segment"],
        "by_variant": attribution["by_variant"],
        "by_language": measured(
            by_language,
            "Genuine events grouped by the creative's recorded language. "
            "'unrecorded' = the event carried no language tag; it is "
            "counted, never guessed."),
        "pacing": delivery["pacing"],
        "freq_cap": delivery["freq_cap"],
        "disclaimers": {
            "pricing": dist.PRICING_DISCLAIMER,
            "revenue": REVENUE_DISCLAIMER,
            "estimates": ("Any figure labeled estimate is estimated "
                          "guidance, never a guaranteed outcome."),
        },
    }
