"""Live Chat Support brain: deterministic intents, tools, tickets, endpoint.

The support brain must NEVER call an external AI provider — every answer
comes from the reviewed knowledge base plus real server-side tool results.
"""
import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import create_token
from app.main import app
from app.models.core import Campaign, CampaignGoal, CampaignStatus, GrowthMode, SupportTicket, User
from app.services.support import brain


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


@pytest_asyncio.fixture
async def user():
    async with SessionLocal() as db:
        u = User(
            email=f"support_{uuid.uuid4().hex[:8]}@test.com",
            name="Support Tester",
            preferred_language="en",
        )
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    yield uid


def _auth(uid) -> dict:
    token = create_token(str(uid), timedelta(minutes=30))
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Intent classification: EN / Urdu script / Roman Urdu / AR
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_intent_greeting_en():
    intent, conf = brain.classify_intent("hello there", "en")
    assert intent == brain.GREETING
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_billing_en():
    intent, conf = brain.classify_intent(
        "how do I pay for a subscription?", "en")
    assert intent == brain.BILLING_GOOGLE_PLAY
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_payment_safety_en():
    # Reported bug: "Is my payment safe?" used to return the billing answer.
    intent, conf = brain.classify_intent("Is my payment safe?", "en")
    assert intent == brain.PAYMENT_SAFETY
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_payment_safety_roman_urdu():
    intent, conf = brain.classify_intent("Kya payment mehfooz hai?", "ur")
    assert intent == brain.PAYMENT_SAFETY
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_payment_safety_arabic():
    intent, conf = brain.classify_intent("هل الدفع آمن؟", "ar")
    assert intent == brain.PAYMENT_SAFETY
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_payment_safety_answer_addresses_safety():
    result = await brain.handle_message("Is my payment safe?", "en", [])
    assert result["intent"] == brain.PAYMENT_SAFETY
    assert "Google Play Billing" in result["answer"]
    assert "never" in result["answer"] and "card" in result["answer"]
    assert any(a.get("route") == "/billing" for a in result["actions"])
    assert len(result["suggestions"]) == 3


@pytest.mark.asyncio
async def test_shop_safety_stays_with_shop():
    # "Is the Shop safe?" must not be stolen by the payment-safety intent.
    for q, lang in [("Is the Shop safe?", "en"),
                    ("Kya Shop mehfooz hai?", "ur"),
                    ("هل المتجر آمن؟", "ar")]:
        intent, conf = brain.classify_intent(q, lang)
        assert intent == brain.FEATURES_SHOP, q
        assert conf >= 0.45


@pytest.mark.asyncio
async def test_previously_unknown_suggestion_chips():
    cases = [
        ("The app won't open", "en", brain.TROUBLESHOOTING_CRASH),
        ("App nahi khul rahi", "ur", brain.TROUBLESHOOTING_CRASH),
        ("I can't log in", "en", brain.TROUBLESHOOTING_LOGIN),
        ("I didn't get the code", "en", brain.LOGIN_OTP),
        ("Shuru kaise karoon?", "ur", brain.HOW_IT_WORKS),
        ("كيف أدفع؟", "ar", brain.BILLING_GOOGLE_PLAY),
        ("عرض حملاتي", "ar", brain.FEATURES_GROW),
        ("ما هو المتجر؟", "ar", brain.FEATURES_SHOP),
        ("كيف تعمل الروابط التابعة؟", "ar", brain.AFFILIATE_DISCLOSURE),
        ("التحدث بالأردية", "ar", brain.LANGUAGE_CHANGE),
    ]
    for q, lang, want in cases:
        intent, conf = brain.classify_intent(q, lang)
        assert intent == want, q
        assert conf >= 0.45, q


@pytest.mark.asyncio
async def test_pure_ticket_request_gets_confirmation_not_create_hub(user):
    # "Create a ticket" misfired on the "create" keyword → features_create.
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        result = await brain.handle_message("Create a ticket", "en", [], u, db)
    assert "ticket_number" in result
    assert f"#{result['ticket_number']}" in result["answer"]
    assert "teleprompter" not in result["answer"].lower()
    assert result["escalated"] is True


@pytest.mark.asyncio
async def test_crash_ticket_keeps_troubleshooting_answer(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        result = await brain.handle_message(
            "my app crashes, please create a ticket", "en", [], u, db)
    assert "ticket_number" in result
    assert f"#{result['ticket_number']}" in result["answer"]
    assert "cache" in result["answer"].lower()


@pytest.mark.asyncio
async def test_intent_free_grow_roman_urdu():
    intent, conf = brain.classify_intent("Free Grow kya hai?", "ur")
    assert intent == brain.FREE_GROW
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_how_it_works_urdu_script():
    intent, conf = brain.classify_intent("یہ کیسے کام کرتا ہے؟", "ur")
    assert intent == brain.HOW_IT_WORKS
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_packages_arabic():
    intent, conf = brain.classify_intent("ما هي الباقات؟", "ar")
    assert intent == brain.PACKAGES_PRICING
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_human_agent_en():
    intent, conf = brain.classify_intent(
        "I want to talk to a real human please", "en")
    assert intent == brain.HUMAN_AGENT
    assert conf >= 0.45


@pytest.mark.asyncio
async def test_intent_unknown_on_garbage():
    intent, conf = brain.classify_intent("zxqw kvlt 9999 !!!", "en")
    assert intent == brain.UNKNOWN
    assert conf < 0.45


@pytest.mark.asyncio
async def test_confidence_formula():
    # 1 hit → 0.60; 2 hits → 0.75; capped at 0.95.
    assert brain._confidence(0) == 0.0
    assert brain._confidence(1) == 0.60
    assert brain._confidence(2) == 0.75
    assert brain._confidence(100) == 0.95


# ---------------------------------------------------------------------------
# Pronoun resolution
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_pronoun_resolution_reuses_last_intent():
    history = [
        {"role": "user", "text": "What are the packages?"},
        {"role": "assistant", "text": "Starter $10/7 days, Growth $25/14 days",
         "intent": brain.PACKAGES_PRICING},
    ]
    cls = brain.classify_message("uski price?", "auto", history)
    assert cls["intent"] == brain.PACKAGES_PRICING
    assert cls["pronoun_resolved"] is True


@pytest.mark.asyncio
async def test_pronoun_without_history_falls_back():
    cls = brain.classify_message("its price?", "auto", [])
    assert cls["intent"] in (brain.PACKAGES_PRICING, brain.UNKNOWN)


# ---------------------------------------------------------------------------
# Tools: get_my_plan / my_campaigns / create_ticket
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_get_my_plan(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        plan = await brain.get_my_plan(u, db)
    assert plan["plan"] == "free"
    assert plan["credits"] == 300


@pytest.mark.asyncio
async def test_my_campaigns(user):
    async with SessionLocal() as db:
        db.add(Campaign(
            user_id=user, title="t1", post_url="https://x.test/1",
            platform="tiktok", goal=CampaignGoal.reach,
            mode=GrowthMode.paid, status=CampaignStatus.live))
        db.add(Campaign(
            user_id=user, title="t2", post_url="https://x.test/2",
            platform="instagram", goal=CampaignGoal.engagement,
            mode=GrowthMode.organic, status=CampaignStatus.paused))
        await db.commit()
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        camps = await brain.my_campaigns(u, db)
    assert camps["count"] == 2
    assert camps["by_status"]["live"] == 1
    assert camps["by_status"]["paused"] == 1


@pytest.mark.asyncio
async def test_create_ticket_persists(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        t = await brain.create_ticket(u, db, "login help", "otp not arriving")
    assert len(t["ticket_number"]) == 6
    assert t["ticket_number"].isupper() or t["ticket_number"].isalnum()
    async with SessionLocal() as db:
        row = (await db.execute(
            select(SupportTicket).where(SupportTicket.user_id == user)
        )).scalar_one()
        assert row.status == "open"
        assert row.subject == "login help"
        assert row.message == "otp not arriving"


@pytest.mark.asyncio
async def test_ticket_request_creates_ticket_and_confirms_number(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        result = await brain.handle_message(
            "my app crashes, please create a ticket", "en", [], u, db)
    assert "ticket_number" in result
    assert f"#{result['ticket_number']}" in result["answer"]
    assert result["escalated"] is True


# ---------------------------------------------------------------------------
# Fallback honesty — never invent facts
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_fallback_is_honest():
    result = await brain.handle_message("zxqw kvlt 9999", "en", [])
    assert result["intent"] == brain.UNKNOWN
    assert "don't have that answer" in result["answer"]
    assert len(result["suggestions"]) == 3


@pytest.mark.asyncio
async def test_paypal_in_no_answer():
    for intent, packs in brain.ANSWERS.items():
        for lang, text in packs.items():
            assert "PayPal" not in text, f"PayPal leaked in {intent}/{lang}"
            assert "Payoneer" not in text, f"Payoneer leaked in {intent}/{lang}"


@pytest.mark.asyncio
async def test_billing_answer_states_google_play():
    text = brain.ANSWERS[brain.BILLING_GOOGLE_PLAY]["en"]
    assert "Google Play Billing" in text


# ---------------------------------------------------------------------------
# answer() contract
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_answer_contract_human_agent():
    result = await brain.handle_message("I want a human agent", "en", [])
    assert result["escalated"] is True
    assert result["intent"] == brain.HUMAN_AGENT
    assert len(result["suggestions"]) == 3
    assert any(a.get("type") == "create_ticket" for a in result["actions"])


@pytest.mark.asyncio
async def test_answer_open_screen_action_shop():
    result = await brain.handle_message("show me the shop", "en", [])
    assert result["intent"] == brain.FEATURES_SHOP
    assert any(a.get("tab") == 4 for a in result["actions"])


@pytest.mark.asyncio
async def test_answer_folds_real_credits(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        result = await brain.handle_message("my credit balance", "en", [], u, db)
    assert result["intent"] == brain.CREDITS
    assert "300" in result["answer"]
    assert "free" in result["answer"]


@pytest.mark.asyncio
async def test_answer_urdu_language():
    result = await brain.handle_message("Free Grow kya hai?", "auto", [])
    assert result["language"] == "ur"
    assert result["answer"]
    assert len(result["suggestions"]) == 3


# ---------------------------------------------------------------------------
# HTTP endpoint: always 200, never 500
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_endpoint_chat_200(client, user):
    r = await client.post(
        "/api/v1/support/chat",
        json={"message": "How does Virello work?", "language": "auto",
              "history": []},
        headers=_auth(user))
    assert r.status_code == 200
    body = r.json()
    assert body["intent"] == brain.HOW_IT_WORKS
    assert body["answer"]
    assert len(body["suggestions"]) == 3
    assert "actions" in body and "escalated" in body


@pytest.mark.asyncio
async def test_endpoint_garbage_empty_long_never_500(client, user):
    for msg in ["", "   ", "asdf qwer zxcv 12345 !@#$",
                "hello " * 500, "\U0001F600" * 200]:
        r = await client.post(
            "/api/v1/support/chat",
            json={"message": msg, "language": "auto"},
            headers=_auth(user))
        assert r.status_code == 200, f"failed on {msg[:30]!r}"
        body = r.json()
        assert "answer" in body and body["answer"]


@pytest.mark.asyncio
async def test_endpoint_escalation_with_history(client, user):
    r = await client.post(
        "/api/v1/support/chat",
        json={"message": "I need a real person",
              "language": "en",
              "history": [{"role": "user", "text": "what are packages?"},
                          {"role": "assistant",
                           "text": "Starter $10",
                           "intent": "packages_pricing"}]},
        headers=_auth(user))
    assert r.status_code == 200
    body = r.json()
    assert body["escalated"] is True
    assert body["intent"] == brain.HUMAN_AGENT


@pytest.mark.asyncio
async def test_old_ai_support_alias_still_works(client, user):
    r = await client.post(
        "/api/v1/ai/support",
        json={"question": "What is Free Grow?", "language": "en"},
        headers=_auth(user))
    assert r.status_code == 200
    body = r.json()
    # Old keys preserved…
    assert "answer" in body and "language" in body and "suggestions" in body
    # …plus the new brain keys.
    assert "actions" in body and "escalated" in body and "intent" in body
    assert "PayPal" not in body["answer"]
