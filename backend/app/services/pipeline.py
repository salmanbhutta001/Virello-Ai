"""AI Growth Orchestrator pipeline — Celery tasks, one per agent stage.

Chain: content_analysis -> audience -> market_research -> strategy -> creative
       -> campaign_launch, then the live loop (analytics -> optimization ->
       budget -> fraud_safety) runs on beat via monitor_live.

Each stage writes an AgentRun row (auditable) and advances campaign status.
Honesty guardrail: outputs are validated before anything reaches the user.
"""
import asyncio
import time
import uuid

from sqlalchemy import select

from app.core.celery_app import celery
from app.core.config import settings
from app.core.database import SessionLocal
from app.models.core import AgentRun, Campaign, CampaignStatus
from app.routers.ai import AGENTS, honesty_check
from app.services.ai import AIRequest, get_ai_provider

# Per-agent system prompts. Shared honesty rules: never promise guaranteed
# virality/followers/sales/reach; optimize honestly; output JSON.
_AGENT_SYSTEM = {
    "content_analysis": (
        "You are Virello's Content Analysis agent. Analyze the post's hook, "
        "clarity, and fit for the stated goal and markets. "
        "NEVER promise guaranteed virality, followers, sales or reach. "
        "Respond with a JSON object: {summary, strengths[], weaknesses[], "
        "score_0_100, confidence_0_1}."
    ),
    "audience": (
        "You are Virello's Audience agent. Describe the audience most likely "
        "to genuinely engage, by market. No fake engagement, no bots. "
        "Respond with a JSON object: {segments[], by_market{}, confidence_0_1}."
    ),
    "market_research": (
        "You are Virello's Market Research agent. Note trends and competitors "
        "relevant to the post and goal. Report honestly; flag uncertainty. "
        "Respond with a JSON object: {trends[], competitors[], opportunities[], "
        "confidence_0_1}."
    ),
    "strategy": (
        "You are Virello's Strategy agent. Produce a growth plan: organic "
        "tactics first; paid only within the approved budget and markets. "
        "Every tactic must cite the metric it aims to improve. "
        "Respond with a JSON object: {tactics[{action, metric, rationale}], "
        "budget_allocation{}, confidence_0_1}."
    ),
    "creative": (
        "You are Virello's Creative agent. Suggest caption/hook/CTA variants "
        "tailored to the goal and markets, in the user's language. "
        "Respond with a JSON object: {variants[{hook, caption, cta}], confidence_0_1}."
    ),
    "campaign_launch": (
        "You are Virello's Campaign agent. Confirm launch readiness: goal, "
        "markets, mode, budget caps. NEVER exceed approved budget/targeting. "
        "Respond with a JSON object: {ready: true|false, checklist[], "
        "budget_caps{}, confidence_0_1}."
    ),
    "analytics": (
        "You are Virello's Analytics agent. Summarize performance honestly: "
        "actuals vs goal, no inflated claims. "
        "Respond with a JSON object: {summary, actuals{}, vs_goal, confidence_0_1}."
    ),
    "optimization": (
        "You are Virello's Optimization agent. Recommend next adjustments "
        "based on actuals. Pause what is ineffective or unsafe. "
        "Respond with a JSON object: {adjustments[{action, reason}], "
        "pause_recommended: true|false, confidence_0_1}."
    ),
    "budget": (
        "You are Virello's Budget agent. Enforce hard caps: daily and total "
        "spend must never exceed the customer-approved budget. "
        "Respond with a JSON object: {spend_status, remaining{}, within_caps: true|false}."
    ),
    "fraud_safety": (
        "You are Virello's Fraud & Safety agent. Flag suspicious traffic, "
        "fake engagement, or policy risk. When in doubt, recommend pausing. "
        "Respond with a JSON object: {flags[], risk_level, pause_recommended: true|false}."
    ),
}


async def _run_stage_async(campaign_id: str, agent: str) -> dict:
    await asyncio.sleep(settings.stage_delay_seconds)
    provider = get_ai_provider()
    try:
        async with SessionLocal() as db:
            res = await db.execute(select(Campaign).where(Campaign.id == uuid.UUID(campaign_id)))
            campaign = res.scalar_one_or_none()
            if campaign is None:
                return {"error": "campaign not found"}

            system = _AGENT_SYSTEM.get(agent, _AGENT_SYSTEM["content_analysis"])

            # Deep post analysis: fetch the real post (oEmbed/OpenGraph),
            # extract features, and score it — feeds the AI prompt with facts.
            analysis_context = ""
            if agent == "content_analysis":
                try:
                    from app.services.analysis.service import (
                        analyze_post, analysis_summary)
                    row = await analyze_post(campaign.post_url, db)
                    facts = analysis_summary(row)
                    score = facts["score"]
                    analysis_context = (
                        "\n--- Real post analysis (analysis engine) ---\n"
                        f"Detected platform: {facts['platform']} "
                        f"(fetch level: {facts['fetch_level']})\n"
                        f"Fetched title: {facts['title']}\n"
                        f"Author: {facts['author']}\n"
                        f"Description: {facts['description'][:300]}\n"
                        f"Media type: {facts['media_type']} | "
                        f"Language: {facts['language']}\n"
                        f"Hashtags: {', '.join(facts['hashtags'][:10])}\n"
                        f"Packaging score: {score['score']}/100 "
                        f"{score['components']}\n"
                        f"Score note: {score['disclaimer']}\n"
                    )
                except Exception as exc:  # analysis must never break launch
                    analysis_context = f"\n(post analysis unavailable: {exc})\n"

            user_prompt = (
                f"Post: {campaign.title}\nPlatform: {campaign.platform}\n"
                f"Goal: {campaign.goal.value}\nMarkets: {campaign.markets}\n"
                f"Mode: {campaign.mode.value}\n"
                f"Budget USD: {campaign.budget_usd} (paid mode only)\n"
                f"Campaign status: {campaign.status.value}"
                f"{analysis_context}"
            )
            resp = await provider.complete(
                AIRequest(agent=agent, system=system, user=user_prompt,
                          max_tokens=800, temperature=0.3, json_mode=True)
            )
            output_text = resp.text
            honest = honesty_check(output_text)
            usage = {
                "provider": resp.provider,
                "model": resp.model,
                "input_tokens": resp.input_tokens,
                "output_tokens": resp.output_tokens,
                "dev": resp.dev,
            }
            db.add(
                AgentRun(
                    campaign_id=campaign.id,
                    agent=agent,
                    input_summary=f"campaign {campaign.id}",
                    output_summary=output_text[:2000],
                    output=usage,
                    honesty_passed=honest,
                    credits_used=5,
                )
            )
            if honest and agent in STATUS_AFTER:
                campaign.status = STATUS_AFTER[agent]
            await db.commit()
            return {"agent": agent, "honesty_passed": honest,
                    "provider": resp.provider, "status": campaign.status.value}
    finally:
        await provider.aclose()

LAUNCH_STAGES = [
    "content_analysis",
    "audience",
    "market_research",
    "strategy",
    "creative",
    "campaign_launch",
]

LIVE_LOOP = ["analytics", "optimization", "budget", "fraud_safety"]

STATUS_AFTER = {
    "content_analysis": CampaignStatus.analyzing,
    "audience": CampaignStatus.analyzing,
    "market_research": CampaignStatus.analyzing,
    "strategy": CampaignStatus.strategizing,
    "creative": CampaignStatus.strategizing,
    "campaign_launch": CampaignStatus.live,
}


def _await_sync(coro):
    """Run a coroutine from sync Celery task code, whether or not an event
    loop is already running (eager mode executes inline inside the request)."""
    import concurrent.futures

    try:
        asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        return pool.submit(lambda: asyncio.run(coro)).result()


@celery.task(name="virello.pipeline.run_stage", bind=True, max_retries=3)
def run_stage(self, campaign_id: str, agent: str) -> dict:  # noqa: ANN001, ANN202
    try:
        return _await_sync(_run_stage_async(campaign_id, agent))
    except Exception as exc:  # noqa: BLE001
        raise self.retry(exc=exc, countdown=60)


@celery.task(name="virello.pipeline.monitor_live")
def monitor_live() -> dict:  # noqa: ANN202
    """Beat task: advance one live-loop stage for every live campaign (round-robin)."""
    async def _go() -> dict:
        async with SessionLocal() as db:
            res = await db.execute(
                select(Campaign).where(Campaign.status == CampaignStatus.live).limit(20)
            )
            campaigns = res.scalars().all()
            ran = 0
            for cp in campaigns:
                agent = LIVE_LOOP[int(time.time() / 300 + hash(cp.id)) % len(LIVE_LOOP)]
                await _run_stage_async(str(cp.id), agent)
                ran += 1
            return {"campaigns_checked": len(campaigns), "stages_ran": ran}

    return _await_sync(_go())


def launch_pipeline(campaign_id: str) -> None:
    """Enqueue the launch chain. Eager mode runs it inline (dev)."""
    from celery import chain

    sigs = [run_stage.si(campaign_id, agent) for agent in LAUNCH_STAGES]
    chain(*sigs).apply_async()
