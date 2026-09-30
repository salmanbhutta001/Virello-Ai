"""Phase 0 — AI Core: intent routing, ask flow, context store, honest fallbacks."""
import uuid

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select

from app.core.database import SessionLocal
from app.main import app
from app.models.ai_core import AIContext, AIConversation, AIIntentLog, AIMessage
from app.models.core import Campaign, User
from app.services.ai_core import router as intent_router
from app.services.ai_core.context import (
    get_context,
    get_recent_messages,
    reset_context,
    update_context,
)
from app.services.ai_core.coordinator import handle_ask


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
            email=f"aicore_{uuid.uuid4().hex[:8]}@test.com",
            name="AI Core Tester",
            preferred_language="en",
        )
        db.add(u)
        await db.commit()
        await db.refresh(u)
        uid = u.id
    yield uid
    # cleanup is best-effort; the test DB is thrown away per session


def _auth(uid) -> dict:
    from datetime import timedelta

    from app.core.security import create_token
    token = create_token(str(uid), timedelta(minutes=30))
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Intent classification
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_classify_create_english():
    intent, conf = intent_router.classify_intent(
        "create 3 video ideas for my bakery", "en")
    assert intent == "create_content"
    assert conf >= 0.6


@pytest.mark.asyncio
async def test_classify_analyze_urdu():
    intent, conf = intent_router.classify_intent(
        "is post ka tajziya karo aur behtar banao", "ur")
    assert intent == "analyze_content"
    assert conf >= 0.5


@pytest.mark.asyncio
async def test_classify_grow_arabic():
    intent, conf = intent_router.classify_intent("أريد حملة لزيادة الوصول", "ar")
    assert intent == "grow"
    assert conf > 0.0


@pytest.mark.asyncio
async def test_classify_url_boosts_analyze():
    intent, conf = intent_router.classify_intent(
        "check this https://example.com/post", "en")
    assert intent == "analyze_content"
    assert conf >= 0.6


@pytest.mark.asyncio
async def test_classify_unknown():
    intent, conf = intent_router.classify_intent("asdfghjkl qwerty zzz", "en")
    assert intent == "unknown"
    assert conf == 0.0


@pytest.mark.asyncio
async def test_no_substring_false_positive():
    # "building" must NOT match "build"/"ui" style substrings (Build #28 lesson).
    intents = intent_router.detect_intents("I am building a house", "en")
    assert intents == []


@pytest.mark.asyncio
async def test_detect_chain_create_and_grow():
    chained = intent_router.detect_intents("create a post and grow it", "en")
    found = [i for i, _ in chained]
    assert "create_content" in found
    assert "grow" in found


@pytest.mark.asyncio
async def test_module_map_shop_is_live():
    shop = intent_router.module_for("shop")
    assert shop["status"] == "live"
    assert shop["phase"] == 4
    assert shop["served_by"] is not None


# ---------------------------------------------------------------------------
# Context store
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_context_create_and_merge(user):
    async with SessionLocal() as db:
        ctx = await get_context(db, user)
        assert ctx.user_id == user
        assert ctx.summary == ""

        ctx = await update_context(
            db, user,
            summary_addenda="likes tech content",
            entities={"niche": "tech"},
            preferences={"language": "en"},
        )
        assert "likes tech content" in ctx.summary
        assert ctx.entities["niche"] == "tech"

        # merge, don't overwrite
        ctx = await update_context(
            db, user,
            summary_addenda="also fitness",
            entities={"niche": "fitness", "goal": "reach"},
        )
        assert "likes tech content" in ctx.summary
        assert "also fitness" in ctx.summary
        assert ctx.entities["niche"] == "fitness"  # new keys win
        assert ctx.entities["goal"] == "reach"
        assert ctx.preferences["language"] == "en"  # untouched

        msgs = await get_recent_messages(db, uuid.uuid4(), limit=5)
        assert msgs == []

        await reset_context(db, user)
        ctx2 = await get_context(db, user)
        assert ctx2.summary == ""
        assert ctx2.id != ctx.id


# ---------------------------------------------------------------------------
# Coordinator: ask flow with dev provider
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_handle_ask_create_uses_dev_provider(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        result = await handle_ask(
            db, u, "create 3 video ideas for my bakery", language="en")
    assert result["intent"] == "create_content"
    assert result["module"] == "creator"
    assert result["dev"] is True
    assert result["provider"] == "dev"
    assert "Development preview" in result["reply"]
    assert result["context_updated"] is True

    async with SessionLocal() as db:
        n_msgs = (await db.execute(
            select(func.count(AIMessage.id)).where(
                AIMessage.conversation_id == uuid.UUID(result["conversation_id"]))))\
            .scalar()
        assert n_msgs == 2  # user + assistant
        n_logs = (await db.execute(
            select(func.count(AIIntentLog.id)).where(
                AIIntentLog.user_id == user))).scalar()
        assert n_logs >= 1


@pytest.mark.asyncio
async def test_handle_ask_shop_uses_real_catalog(user):
    from app.models.commerce import Product
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        db.add(Product(
            creator_id=u.id,
            title="Test Massage Gun Pro",
            description="A deep tissue percussion massager for testing.",
            category="fitness",
            image_urls=["https://example.com/1.jpg", "https://example.com/2.jpg"],
            is_active=True,
        ))
        await db.commit()
        # Specific product question -> real catalog match, never invented.
        result = await handle_ask(
            db, u, "Tell me about this product: Test Massage Gun Pro", language="en")
        assert result["intent"] == "shop"
        assert result["module_status"] == "live"
        assert "Test Massage Gun Pro" in result["reply"]
        assert "Phase 4" not in result["reply"]
        assert any(a.get("path", "").find("shop") >= 0 for a in result["actions"])
        # Unknown product -> honest miss, no invented details.
        miss = await handle_ask(
            db, u, "Tell me about this product: Zzzq Nonexistent Widget 9000",
            language="en")
        assert miss["intent"] == "shop"
        assert "couldn't find" in miss["reply"]
        assert "Test Massage Gun Pro" in miss["reply"]  # real suggestion listed


@pytest.mark.asyncio
async def test_handle_ask_grow_never_auto_executes(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        before = (await db.execute(select(func.count(Campaign.id)))).scalar()
        result = await handle_ask(
            db, u, "grow my campaign and boost reach", language="en")
        after = (await db.execute(select(func.count(Campaign.id)))).scalar()
    assert result["intent"] == "grow"
    assert len(result["actions"]) > 0
    assert before == after  # no campaign auto-created
    assert "never auto-launch" in result["reply"]


@pytest.mark.asyncio
async def test_handle_ask_chain_executes_first_only(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        result = await handle_ask(
            db, u, "create a post and grow it", language="en")
    assert len(result["plan"]) == 2
    assert result["plan"][0]["status"] == "executed"
    assert result["plan"][1]["status"] == "suggested"
    assert "Multi-step plan" in result["reply"]


@pytest.mark.asyncio
async def test_handle_ask_analyze_no_url_asks_for_link(user):
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == user))).scalar_one()
        result = await handle_ask(
            db, u, "analyze my latest post", language="en")
    assert result["intent"] == "analyze_content"
    assert "link" in result["reply"].lower()
    assert any(a["path"] == "/api/v1/analysis/analyze" for a in result["actions"])


# ---------------------------------------------------------------------------
# HTTP endpoints (dev_noauth → dev@virello.app)
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_ask_endpoint_flow(client: httpx.AsyncClient, user):
    h = _auth(user)
    r = await client.post("/api/v1/ai-core/ask", json={
        "text": "create 3 video ideas for my bakery", "language": "en"},
        headers=h)
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["intent"] == "create_content"
    assert j["method"] == "keyword-heuristic-v1"
    assert j["dev"] is True
    cid = j["conversation_id"]

    r = await client.get("/api/v1/ai-core/conversations", headers=h)
    assert r.status_code == 200
    assert any(c["id"] == cid for c in r.json())

    r = await client.get(f"/api/v1/ai-core/conversations/{cid}", headers=h)
    assert r.status_code == 200
    roles = [m["role"] for m in r.json()]
    # get_recent_messages returns newest-first by design
    assert roles == ["assistant", "user"]

    r = await client.get("/api/v1/ai-core/context", headers=h)
    assert r.status_code == 200
    assert "[create_content]" in r.json()["summary"]

    r = await client.delete("/api/v1/ai-core/context", headers=h)
    assert r.status_code == 200
    assert r.json()["reset"] is True
    r = await client.get("/api/v1/ai-core/context", headers=h)
    assert r.json()["summary"] == ""


@pytest.mark.asyncio
async def test_conversation_ownership_404(client: httpx.AsyncClient, user):
    h = _auth(user)
    r = await client.get(f"/api/v1/ai-core/conversations/{uuid.uuid4()}",
                         headers=h)
    assert r.status_code == 404
    r = await client.get("/api/v1/ai-core/conversations/not-a-uuid", headers=h)
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_intents_endpoint_public(client: httpx.AsyncClient):
    r = await client.get("/api/v1/ai-core/intents")
    assert r.status_code == 200
    j = r.json()
    assert j["method"] == "keyword-heuristic-v1"
    intents = {i["intent"]: i for i in j["intents"]}
    assert intents["shop"]["status"] == "live"
    assert intents["grow"]["status"] == "live"


@pytest.mark.asyncio
async def test_ask_requires_text(client: httpx.AsyncClient, user):
    r = await client.post("/api/v1/ai-core/ask", json={"text": ""},
                          headers=_auth(user))
    assert r.status_code == 422
