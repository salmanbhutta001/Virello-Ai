"""Free Grow vs Paid Boost — plan limits and paid packages.

Two campaign plans, shown as separate modules in the app:

FREE GROW ("free")
  - Worldwide audience only, zero budget, no spend ever accrues.
  - LIMITED: at most FREE_PLAN_MAX_ACTIVE_CAMPAIGNS live campaigns per
    advertiser, and each free campaign stops delivering after
    FREE_PLAN_MAX_IMPRESSIONS genuine impressions (then auto-completes).
  - No budget UI, no country targeting.

PAID BOOST ("paid")
  - No manual budgeting: the advertiser picks one of PAID_PACKAGES.
    Each package is a fixed price + fixed duration; that becomes the
    campaign's advertiser-approved budget.
  - Country targeting available (AI-recommended / worldwide / custom).

Everything here is data, not inference: limits and packages are explicit
constants so the app can display them honestly and support can change
them without code archaeology.
"""
from __future__ import annotations

# ---------------------------------------------------------------- Free plan
FREE_PLAN_MAX_ACTIVE_CAMPAIGNS = 3
# Live states that count against the free campaign quota: drafts don't
# (the advertiser may abandon them), completed/rejected don't (they're done).
FREE_PLAN_COUNTED_STATUSES = (
    "pending_approval", "approved", "active", "paused")
# Genuine impressions after which a free campaign auto-completes.
FREE_PLAN_MAX_IMPRESSIONS = 1000

FREE_PLAN_SUMMARY = {
    "plan": "free",
    "name": "Free Grow",
    "price_usd": 0,
    "audience": "Worldwide only",
    "limits": {
        "max_active_campaigns": FREE_PLAN_MAX_ACTIVE_CAMPAIGNS,
        "max_impressions_per_campaign": FREE_PLAN_MAX_IMPRESSIONS,
        "country_targeting": False,
        "budget": False,
    },
    "note": ("Free Grow is a limited free tier: worldwide audience only, "
             "up to 3 live campaigns at a time, and each campaign stops "
             "delivering after 1,000 genuine impressions."),
}

# ---------------------------------------------------------------- Paid plan
PAID_PACKAGES = [
    {
        "id": "starter",
        "name": "Starter Boost",
        "price_usd": 10.0,
        "duration_days": 7,
        "tagline": "Test the waters with your first boost.",
        "features": [
            "Country targeting (AI-recommended or your picks)",
            "AI audience matching",
            "Reach & engagement analytics",
        ],
    },
    {
        "id": "growth",
        "name": "Growth Boost",
        "price_usd": 25.0,
        "duration_days": 14,
        "tagline": "Two weeks of steady AI-driven growth.",
        "features": [
            "Everything in Starter",
            "A/B creative variants",
            "AI distribution optimization",
        ],
        "popular": True,
    },
    {
        "id": "pro",
        "name": "Pro Boost",
        "price_usd": 50.0,
        "duration_days": 30,
        "tagline": "A full month with the AI growth agent.",
        "features": [
            "Everything in Growth",
            "Conversion attribution",
            "Per-segment performance insights",
        ],
    },
    {
        "id": "scale",
        "name": "Scale Boost",
        "price_usd": 100.0,
        "duration_days": 30,
        "tagline": "Maximum reach for launches that matter.",
        "features": [
            "Everything in Pro",
            "Highest reach estimate of all packages",
            "Full-funnel reporting: reach to conversions",
        ],
    },
]

_PAID_BY_ID = {p["id"]: p for p in PAID_PACKAGES}


def get_package(package_id: str | None) -> dict | None:
    """Return the paid package dict, or None for blank input."""
    if not package_id:
        return None
    return _PAID_BY_ID.get(str(package_id).strip().lower())


def packages_payload() -> dict:
    """Public payload for GET /api/v1/ads/packages + the free plan summary."""
    return {
        "free": FREE_PLAN_SUMMARY,
        "paid": {
            "plan": "paid",
            "name": "Paid Boost",
            "note": ("Paid Boost has no manual budgeting — pick a package. "
                     "The package price is the full advertiser-approved "
                     "budget; spend can never exceed it."),
            "packages": [dict(p) for p in PAID_PACKAGES],
        },
        "disclaimer": "Estimates are not guarantees; see each campaign.",
    }
