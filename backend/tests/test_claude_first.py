"""Claude-first attachment across Creator Hub tools (Hafiz 2026-10-21):
provider selection, create._ai_json, video direction, story endpoint."""
from __future__ import annotations

import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio

import app.routers.create as create
import app.routers.video as video
from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import create_token
from app.main import app
from app.models.core import User
from app.services.ai.base import (
    AIResponse,
    AnthropicProvider,
    DevMuseProvider,
    get_claude_first_provider,
)


class _FakeProvider:
    name = "fake"

    def __init__(self, text: str = "{}", dev: bool = False, boom: bool = False):
        self._text, self._dev, self._boom = text, dev, boom

    async def complete(self, req):
        if self._boom:
            raise RuntimeError("provider down")
        return AIResponse(text=self._text, provider="fake", model="f-1",
                          dev=self._dev)


# ---------------------------------------------------------------------------
# Provider selection
# ---------------------------------------------------------------------------

def test_claude_first_prefers_anthropic_with_key(monkeypatch):
    monkeypatch.setattr(settings, "anthropic_api_key", "sk-ant-test")
    assert isinstance(get_claude_first_provider(), AnthropicProvider)


def test_claude_first_falls_back_to_configured(monkeypatch):
    monkeypatch.setattr(settings, "anthropic_api_key", "")
    monkeypatch.setattr(settings, "ai_provider", "dev")
    assert isinstance(get_claude_first_provider(), DevMuseProvider)


# ---------------------------------------------------------------------------
# Creator Hub text tools (ideas/scripts/captions/hooks via _ai_json)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ai_json_uses_claude_first(monkeypatch):
    monkeypatch.setattr(create, "get_claude_first_provider",
                        lambda: _FakeProvider('{"ideas": []}'))
    data, provider, dev = await create._ai_json("creator", "sys", "user")
    assert data == {"ideas": []}
    assert provider == "fake"
    assert dev is False


@pytest.mark.asyncio
async def test_ai_json_failure_falls_back_honestly(monkeypatch):
    monkeypatch.setattr(create, "get_claude_first_provider",
                        lambda: _FakeProvider(boom=True))
    data, provider, dev = await create._ai_json("creator", "sys", "user")
    assert data is None
    assert dev is True


# ---------------------------------------------------------------------------
# Create Video direction stage
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_video_direction_enhances(monkeypatch):
    monkeypatch.setattr(
        "app.services.ai.base.get_claude_first_provider",
        lambda: _FakeProvider("A cat chases a laser dot across a sunny "
                              "rooftop, tracking shot, golden light"))
    out = await video._direct_video_prompt("cat playing")
    assert out is not None and "laser" in out


@pytest.mark.asyncio
async def test_video_direction_dev_returns_none(monkeypatch):
    monkeypatch.setattr(
        "app.services.ai.base.get_claude_first_provider",
        lambda: _FakeProvider("whatever", dev=True))
    assert await video._direct_video_prompt("cat playing") is None


@pytest.mark.asyncio
async def test_video_direction_failure_returns_none(monkeypatch):
    monkeypatch.setattr(
        "app.services.ai.base.get_claude_first_provider",
        lambda: _FakeProvider(boom=True))
    assert await video._direct_video_prompt("cat playing") is None


# ---------------------------------------------------------------------------
# AI Story endpoint runs on the Claude-first provider
# ---------------------------------------------------------------------------

@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_story_endpoint_uses_claude_first(client, monkeypatch):
    monkeypatch.setattr(
        "app.routers.entertain.get_claude_first_provider",
        lambda: _FakeProvider("A Small Light\n\nMina shared her lantern "
                              "with the whole street."))
    async with SessionLocal() as db:
        user = User(email=f"story-{uuid.uuid4().hex[:8]}@example.com",
                    name="Story")
        db.add(user)
        await db.commit()
        token = create_token(str(user.id), timedelta(minutes=30))
    r = await client.post(
        "/api/v1/entertain/story",
        json={"topic": "kindness", "length": "short", "language": "en"},
        headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["provider"] == "fake"
    assert data["dev"] is False
    assert data["story"]["title"] == "A Small Light"
    assert "lantern" in data["story"]["body"]
