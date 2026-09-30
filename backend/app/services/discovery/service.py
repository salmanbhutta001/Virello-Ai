"""Discovery service: interests, feed, interactions, placements."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

log = logging.getLogger(__name__)

from app.models.commerce import PostProduct, Product
from app.models.core import AuditLog, Campaign, CampaignStatus, FraudFlag, User
from app.models.growth import (
    DiscoveryInteraction, DiscoveryPlacement, PostAnalysis, Topic, UserInterest,
)
from app.services.affiliate.amazon import AmazonAffiliateProvider
from .matcher import score_candidate
from .topics_seed import seed_topics

INTERACTION_KINDS = {"view", "save", "visit", "dismiss", "like"}

# ---------------------------------------------------------------- tagged products
# Shoppable posts: each feed item carries placement_id + tagged_products
# (product cards with an affiliate disclosure flag for the mobile UI).
# Batched: one query for PostProduct rows, one for the matching Products.


def _price_display(price_cents: int, currency: str) -> str:
    symbols = {"USD": "$", "EUR": "€", "GBP": "£", "PKR": "Rs ",
               "INR": "₹", "AED": "د.إ "}
    cur = (currency or "USD").upper()
    return f"{symbols.get(cur, cur + ' ')}{price_cents / 100:,.2f}"


def _product_card(asin: str, p: Product) -> dict:
    images = p.image_urls or []
    return {
        "asin": asin,
        "title": p.title,
        "image_url": images[0] if images else "",
        "price_cents": p.price_cents,
        "currency": p.currency,
        "price_display": _price_display(p.price_cents, p.currency),
        "is_affiliate": True,  # mobile shows "Affiliate link" disclosure
    }


async def tagged_products_for_placements(
        db: AsyncSession, placement_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[dict]]:
    """Map placement_id -> tagged product cards. Two queries, no N+1."""
    out: dict[uuid.UUID, list[dict]] = {}
    if not placement_ids:
        return out
    pp_rows = (await db.execute(select(PostProduct).where(
        PostProduct.post_id.in_(placement_ids)))).scalars().all()
    if not pp_rows:
        return out
    provider = AmazonAffiliateProvider()
    asins = sorted({r.asin for r in pp_rows})
    urls = [provider.build_affiliate_url(a) for a in asins]
    prods = (await db.execute(select(Product).where(
        Product.affiliate_url.in_(urls),
        Product.is_active.is_(True)))).scalars().all()
    by_url = {p.affiliate_url: p for p in prods}
    for r in pp_rows:
        p = by_url.get(provider.build_affiliate_url(r.asin))
        if p is None:
            continue
        out.setdefault(r.post_id, []).append(_product_card(r.asin, p))
    return out


async def get_my_interests(db: AsyncSession, user_id: uuid.UUID) -> list[str]:
    rows = (await db.execute(
        select(UserInterest.topic_slug).where(UserInterest.user_id == user_id))).all()
    return [r[0] for r in rows]


async def set_my_interests(db: AsyncSession, user_id: uuid.UUID,
                           slugs: list[str]) -> list[str]:
    await seed_topics(db)
    valid = {r[0] for r in (await db.execute(
        select(Topic.slug).where(Topic.active.is_(True)))).all()}
    clean = sorted({s for s in slugs if s in valid})[:20]
    old = await get_my_interests(db, user_id)
    for slug in old:
        if slug not in clean:
            await db.execute(UserInterest.__table__.delete().where(
                UserInterest.user_id == user_id, UserInterest.topic_slug == slug))
    for slug in clean:
        if slug not in old:
            db.add(UserInterest(user_id=user_id, topic_slug=slug))
    await db.commit()
    return clean


async def request_placement(db: AsyncSession, user_id: uuid.UUID,
                            campaign_id: uuid.UUID, topics: list[str]) -> DiscoveryPlacement:
    """Creator opts a campaign into discovery. Auto-approves when the campaign
    is live with no open fraud flags; otherwise it waits for admin review."""
    campaign = (await db.execute(select(Campaign).where(
        Campaign.id == campaign_id, Campaign.user_id == user_id))).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Campaign not found")
    await seed_topics(db)
    valid = {r[0] for r in (await db.execute(
        select(Topic.slug).where(Topic.active.is_(True)))).all()}
    clean = sorted({t for t in topics if t in valid})[:5]
    if not clean:
        raise ValueError("Pick at least one valid topic")

    placement = (await db.execute(select(DiscoveryPlacement).where(
        DiscoveryPlacement.campaign_id == campaign_id))).scalar_one_or_none()
    if placement is None:
        placement = DiscoveryPlacement(campaign_id=campaign_id)
        db.add(placement)
    placement.topics = clean

    flags = (await db.execute(select(FraudFlag).where(
        FraudFlag.campaign_id == campaign_id,
        FraudFlag.resolved.is_(False)))).scalars().all()
    if campaign.status == CampaignStatus.live and not flags:
        placement.status = "approved"
        placement.review_note = "auto-approved: live campaign, no open fraud flags"
        placement.reviewed_at = datetime.now(timezone.utc)
    else:
        placement.status = "pending"
        placement.review_note = "awaiting review"
        placement.reviewed_at = None
    db.add(AuditLog(user_id=user_id, action="discovery.placement.request",
                    details=f"campaign={campaign_id} topics={clean}"))
    await db.commit()
    await db.refresh(placement)
    return placement


async def get_feed(db: AsyncSession, user: User, limit: int = 20,
                   offset: int = 0) -> list[dict]:
    """Personalized discovery feed — only approved placements of live
    campaigns, excluding the user's own campaigns and dismissed items."""
    await seed_topics(db)
    interests = set(await get_my_interests(db, user.id))
    topic_rows = (await db.execute(select(Topic))).scalars().all()
    names = {t.slug: (t.name_ur if user.locale == "ur" else t.name_en)
             for t in topic_rows}

    dismissed = {r[0] for r in (await db.execute(
        select(DiscoveryInteraction.campaign_id).where(
            DiscoveryInteraction.user_id == user.id,
            DiscoveryInteraction.kind == "dismiss"))).all()}
    seen = {r[0] for r in (await db.execute(
        select(DiscoveryInteraction.campaign_id).where(
            DiscoveryInteraction.user_id == user.id,
            DiscoveryInteraction.kind.in_(("view", "save", "visit"))))).all()}

    stmt = (select(DiscoveryPlacement, Campaign)
            .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
            .where(DiscoveryPlacement.status == "approved",
                   Campaign.status == CampaignStatus.live,
                   Campaign.user_id != user.id))
    rows = (await db.execute(stmt)).all()

    # Language per campaign from its post analysis (best effort).
    analyses = {}
    for _placement, campaign in rows:
        a = (await db.execute(select(PostAnalysis).where(
            PostAnalysis.url == campaign.post_url))).scalar_one_or_none()
        # post_url may differ in normalization; fall back gracefully
        meta = (a.language_metadata or {}) if a else {}
        langs = [meta.get("primary") or (a.language if a else "unknown")]
        if meta.get("is_mixed_language"):
            for alt in meta.get("alternatives", []):
                if alt.get("code") not in langs:
                    langs.append(alt["code"])
        analyses[campaign.id] = {
            "primary": langs[0] if langs[0] else "unknown",
            "languages": [l for l in langs if l],
            "uncertain": bool(meta.get("detection_uncertain", False)),
        }

    user_langs = [user.preferred_language or user.locale or "en"]
    for extra in (user.content_languages or []):
        if extra not in user_langs:
            user_langs.append(extra)

    scored = []
    for placement, campaign in rows:
        if campaign.id in dismissed or campaign.id in seen:
            continue
        lang_info = analyses[campaign.id]
        match = score_candidate(
            user_topics=interests, user_locale=user.locale or "en",
            placement_topics=placement.topics or [],
            campaign_markets=(campaign.markets or "").split(","),
            campaign_language=lang_info["primary"],
            campaign_languages=lang_info["languages"],
            language_uncertain=lang_info["uncertain"],
            user_languages=user_langs,
            all_relevant_languages=bool(user.all_relevant_languages),
            campaign_created_at=campaign.created_at,
            topic_names=names)
        # AI Growth Engine: segment boost + variant rotation (genuine
        # personalization — the same real placement, ranked/presented smarter).
        growth = None
        boost, variant = 1.0, None
        segment_id = None
        try:
            from app.services import growth_engine as _engine
            ctx = await _engine.loop_context(db, campaign.id)
        except Exception:
            ctx = None
        if ctx:
            boost, segment_id = _engine.segment_boost(
                ctx["segments"], interests)
            if ctx["variants"]:
                variant = _engine.pick_variant(
                    ctx["variants"], user.id, campaign.id)
            growth = {
                "loop_id": str(ctx["loop"].id),
                "boost": round(boost, 3),
                "segment_id": str(segment_id) if segment_id else None,
            }
        final_score = match["score"] * boost
        # Ranked for everyone: with interests, topic matches float up;
        # without interests, market/language/freshness still rank sensibly.
        scored.append((final_score, match, placement, campaign,
                       growth, variant))
    scored.sort(key=lambda x: x[0], reverse=True)

    page = scored[offset:offset + limit]
    tagged = await tagged_products_for_placements(
        db, [placement.id for _, _, placement, _, _, _ in page])

    # Per-post cash badge: each placement's own reward_cents, else the
    # admin-tunable default (Hafiz: +$0.05). Fetched once for the page.
    from app.services import reward_claims as _claims
    default_reward = await _claims.get_default_post_reward_cents(db)

    items = []
    for final_score, match, placement, campaign, growth, variant in page:
        lang_info = analyses[campaign.id]
        reward_cents = (placement.reward_cents
                        if placement.reward_cents is not None
                        else default_reward)
        item = {
            "campaign_id": str(campaign.id),
            "placement_id": str(placement.id),
            "title": campaign.title,
            "platform": campaign.platform,
            "goal": campaign.goal.value,
            "post_url": campaign.post_url,
            "thumbnail_url": "",
            "match_score": match["score"],
            "match_reasons": match["reasons"],
            # Cash badge for the share row: "+$0.05". Tapping it shows
            # "Share to earn $0.05". Per-post amounts differ.
            "reward_cents": reward_cents,
            "reward_display": _claims.fmt_reward(reward_cents),
            # Original-language badge + cross-language match info.
            "content_language": lang_info["primary"],
            "content_languages": lang_info["languages"],
            "language_uncertain": lang_info["uncertain"],
            "tagged_products": tagged.get(placement.id, []),
        }
        if growth:
            item["growth"] = growth
            if variant is not None:
                content = variant.content or {}
                item["growth_variant"] = {
                    "variant_id": str(variant.id),
                    "label": variant.label,
                    "title": content.get("title") or campaign.title,
                    "caption": content.get("caption") or "",
                    "hashtags": content.get("hashtags") or [],
                    "is_original": variant.is_original,
                }
        items.append(item)
    return items


async def record_interaction(db: AsyncSession, user_id: uuid.UUID,
                             campaign_id: uuid.UUID, kind: str,
                             variant_id: uuid.UUID | None = None) -> dict:
    if kind not in INTERACTION_KINDS:
        raise ValueError(f"kind must be one of {sorted(INTERACTION_KINDS)}")
    campaign = (await db.execute(select(Campaign).where(
        Campaign.id == campaign_id))).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Campaign not found")
    if variant_id is not None:
        # The variant must belong to this campaign's growth loop — the client
        # echoes what the feed actually displayed; we verify it's legitimate.
        from app.models.growth_engine import GrowthLoop, GrowthVariant
        ok = (await db.execute(
            select(GrowthVariant.id)
            .join(GrowthLoop, GrowthLoop.id == GrowthVariant.loop_id)
            .where(GrowthVariant.id == variant_id,
                   GrowthLoop.campaign_id == campaign_id)
        )).scalar_one_or_none()
        if ok is None:
            raise ValueError("Unknown variant for this campaign")
    existing = (await db.execute(select(DiscoveryInteraction).where(
        DiscoveryInteraction.user_id == user_id,
        DiscoveryInteraction.campaign_id == campaign_id,
        DiscoveryInteraction.kind == kind))).scalar_one_or_none()
    if existing is None:
        interaction = DiscoveryInteraction(user_id=user_id,
                                           campaign_id=campaign_id,
                                           kind=kind, variant_id=variant_id)
        db.add(interaction)
        await db.commit()
        await db.refresh(interaction)
        if kind == "like":
            # Points to the post owner for a genuine like (no self-likes).
            try:
                from app.services import rewards as rewards_svc
                await rewards_svc.award_like_received(
                    db, campaign_id, user_id, interaction.id)
            except Exception:
                log.exception("rewards: like_received hook failed")
        return {"recorded": True, "kind": kind}
    return {"recorded": False, "kind": kind, "note": "already recorded"}


async def get_placement_stats(db: AsyncSession, user_id: uuid.UUID,
                              campaign_id: uuid.UUID) -> dict:
    campaign = (await db.execute(select(Campaign).where(
        Campaign.id == campaign_id, Campaign.user_id == user_id))).scalar_one_or_none()
    if campaign is None:
        raise ValueError("Campaign not found")
    rows = (await db.execute(
        select(DiscoveryInteraction))).scalars().all()
    stats = {k: 0 for k in INTERACTION_KINDS}
    for r in rows:
        if r.campaign_id == campaign_id:
            stats[r.kind] = stats.get(r.kind, 0) + 1
    placement = (await db.execute(select(DiscoveryPlacement).where(
        DiscoveryPlacement.campaign_id == campaign_id))).scalar_one_or_none()
    return {
        "campaign_id": str(campaign_id),
        "placement_status": placement.status if placement else "none",
        "interactions": stats,   # real user actions only — never inflated
        "note": "Counts reflect genuine opted-in user actions.",
    }
