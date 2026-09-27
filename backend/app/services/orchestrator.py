"""AI Growth Orchestrator — runs the 10 specialized agents as a Celery pipeline.

Pipeline:
  content_analysis -> (audience + market_research) -> strategy
  -> creative -> campaign (launch within approved limits)
  -> live loop: analytics -> optimization -> budget guard -> fraud_safety gate
Support agent serves in-app help alongside.

Every agent output passes honesty_check() before it reaches the user.
"""
from app.routers.ai import AGENTS, honesty_check

PIPELINE = [
    "content_analysis",
    "audience",
    "market_research",
    "strategy",  # composed from audience+market outputs
    "creative",
    "campaign",
    # live loop:
    "analytics",
    "optimization",
    "budget",
    "fraud_safety",
]


def run_stage(agent: str, campaign_id: str, payload: dict) -> dict:
    """Celery task body (simplified). Real version: LLM call + tool use + schema validation."""
    assert agent in AGENTS or agent == "strategy", f"unknown agent {agent}"
    output = f"[{agent}] draft result for campaign {campaign_id}"
    if not honesty_check(output):
        return {"agent": agent, "blocked": True, "reason": "honesty_check failed"}
    return {"agent": agent, "output": output, "honesty_passed": True}
