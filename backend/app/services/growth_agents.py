"""Free Grow AI vs Paid Boost AI — the two growth agents.

Hafiz's concept: Free services and Paid services get their OWN AI agents,
because they manage fundamentally different things:

- FREE GROW AI ("free_growth_agent") manages Free Grow campaigns: organic
  discovery only — worldwide audience, zero budget, limited
  (FREE_PLAN_MAX_ACTIVE_CAMPAIGNS live campaigns per advertiser,
  FREE_PLAN_MAX_IMPRESSIONS genuine impressions per campaign). It tunes
  creative rotation and segment weights from genuine engagement, and it
  knows the free limits: near the impression cap it winds down expansion
  and says so honestly. It never touches money — there is none.

- PAID BOOST AI ("paid_growth_agent") manages Paid Boost campaigns:
  everything the free agent does, PLUS budget pacing guardrails,
  cost-efficiency tuning (results per dollar of the package budget),
  geo-segment optimization for country targeting, and package awareness
  (fixed price + duration — no manual budgeting on Paid Boost).

Both agents share the same safety rails — fraud auto-pause, minimum-sample
guards, every decision explainable and audited — they differ in policy,
never in honesty. Neither agent ever guarantees reach, followers, or
sales.
"""
from __future__ import annotations

from app.services import plans as plans_svc

FREE_GROWTH_AGENT = "free_growth_agent"
PAID_GROWTH_AGENT = "paid_growth_agent"

# All agent names ever used, so audit-trail queries stay backward
# compatible (older rows used agent="optimizer").
ALL_GROWTH_AGENTS = (FREE_GROWTH_AGENT, PAID_GROWTH_AGENT, "optimizer")

# Fraction of the free impression cap at which the Free Grow AI starts
# winding down expansion (no new variants, no weight increases) and tells
# the advertiser the limit is approaching.
FREE_WIND_DOWN_FRACTION = 0.8


def agent_for_plan(plan: str | None) -> str:
    """Which growth agent manages a campaign of this plan."""
    if (plan or "").strip().lower() == "free":
        return FREE_GROWTH_AGENT
    return PAID_GROWTH_AGENT


def agent_descriptor(agent: str) -> dict:
    """Public description of an agent for the app UI."""
    if agent == FREE_GROWTH_AGENT:
        return {
            "id": FREE_GROWTH_AGENT,
            "name": "Free Grow AI",
            "tagline": ("Your organic growth manager — worldwide reach, "
                        "zero budget."),
            "manages": "free",
            "capabilities": [
                "Worldwide audience matching",
                "Creative variant rotation from genuine engagement",
                "Segment tuning for organic discovery",
                "Free-limit awareness — winds down near the impression cap",
            ],
            "limits": [
                "No budget to manage — Free Grow is $0",
                "No country targeting (worldwide only)",
                (f"Each campaign stops at "
                 f"{plans_svc.FREE_PLAN_MAX_IMPRESSIONS:,} genuine "
                 f"impressions"),
            ],
        }
    return {
        "id": PAID_GROWTH_AGENT,
        "name": "Paid Boost AI",
        "tagline": ("Your paid growth manager — targeted reach, inside "
                    "your package budget."),
        "manages": "paid",
        "capabilities": [
            "Country-targeted audience matching",
            "Creative variant rotation from genuine engagement",
            "Budget pacing guardrails — spend never exceeds the package",
            "Cost-efficiency tuning (results per dollar)",
            "Package-aware delivery (fixed price + duration)",
        ],
        "limits": [
            "Never spends more than the chosen package price",
            "No manual budgeting — packages only",
            "Every decision explainable and audited",
        ],
    }


def agents_payload() -> dict:
    """Public payload for GET /api/v1/ads/agents."""
    return {
        "agents": [agent_descriptor(FREE_GROWTH_AGENT),
                   agent_descriptor(PAID_GROWTH_AGENT)],
        "note": ("Each campaign is managed by exactly one AI agent, chosen "
                 "by its plan. The agent is shown on the campaign and in "
                 "every audited decision it makes."),
    }
