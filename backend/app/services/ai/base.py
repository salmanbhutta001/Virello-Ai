"""Abstract AI provider interface + factory."""
from __future__ import annotations

import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

import httpx

from app.core.config import settings


class AIProviderError(Exception):
    """The provider call failed (network, API error, bad response)."""


class AIProviderNotConfigured(Exception):
    """The selected provider has no credentials/model configured. Fail closed."""


@dataclass
class AIRequest:
    agent: str                      # e.g. "content_analysis"
    system: str                     # system prompt (role + rules)
    user: str                       # user prompt (the task)
    max_tokens: int = 1024
    temperature: float = 0.3
    json_mode: bool = True          # ask for a JSON object back
    metadata: dict = field(default_factory=dict)


@dataclass
class AIResponse:
    text: str
    provider: str
    model: str
    input_tokens: int = 0
    output_tokens: int = 0
    latency_ms: int = 0
    dev: bool = False               # True only for the dev/prototyping provider


class AIProvider(ABC):
    """Every model backend implements this. Keep it small on purpose."""

    name: str = "base"

    @abstractmethod
    async def complete(self, req: AIRequest) -> AIResponse:
        ...

    async def aclose(self) -> None:
        """Override when the provider holds resources (http client)."""


def _http() -> httpx.AsyncClient:
    return httpx.AsyncClient(timeout=httpx.Timeout(60.0, connect=10.0))


class _RestProvider(AIProvider):
    """Shared HTTP plumbing for real model APIs."""

    model: str = ""

    def __init__(self) -> None:
        self._client: httpx.AsyncClient | None = None

    def _client_or_raise(self, api_key: str) -> httpx.AsyncClient:
        if not api_key or not self.model:
            raise AIProviderNotConfigured(
                f"{self.name}: set {self._key_env()} and {self._model_env()} to use it"
            )
        if self._client is None:
            self._client = _http()
        return self._client

    def _key_env(self) -> str:  # pragma: no cover - overridden
        return "API_KEY"

    def _model_env(self) -> str:  # pragma: no cover - overridden
        return "MODEL"

    async def aclose(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None


# ---------------------------------------------------------------------------
# Development / prototyping provider (available Muse AI environment)
# ---------------------------------------------------------------------------
class DevMuseProvider(AIProvider):
    """Deterministic dev provider. Exercises the whole pipeline end-to-end
    without any API key. NEVER used silently: every response is labeled dev."""

    name = "dev"
    model = "muse-dev"

    async def complete(self, req: AIRequest) -> AIResponse:
        start = time.monotonic()
        text = _dev_template(req)
        return AIResponse(
            text=text,
            provider=self.name,
            model=self.model,
            input_tokens=len(req.system + req.user) // 4,
            output_tokens=len(text) // 4,
            latency_ms=int((time.monotonic() - start) * 1000),
            dev=True,
        )


def _dev_template(req: AIRequest) -> str:
    import json

    payload = {
        "agent": req.agent,
        "dev": True,
        "note": "Development/prototyping output from the Muse AI environment. "
                "Connect a production provider via VIRELLO_AI_PROVIDER for real analysis.",
        "summary": f"Dev analysis for agent '{req.agent}'.",
        "recommendations": [
            "Hook: lead with the strongest visual within 2 seconds.",
            "Caption: one clear idea, native language of the target market.",
            "Post when the target audience is most active; reply to early comments.",
        ],
        "confidence": 0.5,
    }
    return json.dumps(payload)


# ---------------------------------------------------------------------------
# Anthropic
# ---------------------------------------------------------------------------
class AnthropicProvider(_RestProvider):
    name = "anthropic"

    def __init__(self, api_key: str = "", model: str = "") -> None:
        super().__init__()
        self._api_key = api_key or settings.anthropic_api_key
        self.model = model or settings.anthropic_model

    def _key_env(self) -> str:
        return "VIRELLO_ANTHROPIC_API_KEY"

    def _model_env(self) -> str:
        return "VIRELLO_ANTHROPIC_MODEL"

    async def complete(self, req: AIRequest) -> AIResponse:
        client = self._client_or_raise(self._api_key)
        start = time.monotonic()
        body: dict = {
            "model": self.model,
            "max_tokens": req.max_tokens,
            "temperature": req.temperature,
            "system": req.system,
            "messages": [{"role": "user", "content": req.user}],
        }
        try:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": self._api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise AIProviderError(f"anthropic: {exc}") from exc
        blocks = data.get("content", [])
        text = "".join(b.get("text", "") for b in blocks if b.get("type") == "text")
        usage = data.get("usage", {})
        return AIResponse(
            text=text, provider=self.name, model=self.model,
            input_tokens=int(usage.get("input_tokens", 0)),
            output_tokens=int(usage.get("output_tokens", 0)),
            latency_ms=int((time.monotonic() - start) * 1000),
        )


# ---------------------------------------------------------------------------
# OpenAI
# ---------------------------------------------------------------------------
class OpenAIProvider(_RestProvider):
    name = "openai"

    def __init__(self, api_key: str = "", model: str = "") -> None:
        super().__init__()
        self._api_key = api_key or settings.openai_api_key
        self.model = model or settings.openai_model

    def _key_env(self) -> str:
        return "VIRELLO_OPENAI_API_KEY"

    def _model_env(self) -> str:
        return "VIRELLO_OPENAI_MODEL"

    async def complete(self, req: AIRequest) -> AIResponse:
        client = self._client_or_raise(self._api_key)
        start = time.monotonic()
        body: dict = {
            "model": self.model,
            "temperature": req.temperature,
            "max_tokens": req.max_tokens,
            "messages": [
                {"role": "system", "content": req.system},
                {"role": "user", "content": req.user},
            ],
        }
        if req.json_mode:
            body["response_format"] = {"type": "json_object"}
        try:
            resp = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"authorization": f"Bearer {self._api_key}"},
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise AIProviderError(f"openai: {exc}") from exc
        choice = (data.get("choices") or [{}])[0]
        text = ((choice.get("message") or {}).get("content") or "")
        usage = data.get("usage", {})
        return AIResponse(
            text=text, provider=self.name, model=self.model,
            input_tokens=int(usage.get("prompt_tokens", 0)),
            output_tokens=int(usage.get("completion_tokens", 0)),
            latency_ms=int((time.monotonic() - start) * 1000),
        )


# ---------------------------------------------------------------------------
# Groq (OpenAI-compatible API, fast inference)
# Hafiz 2026-10-13: Groq API key provided for text AI features.
# ---------------------------------------------------------------------------
class GroqProvider(_RestProvider):
    name = "groq"

    def __init__(self, api_key: str = "", model: str = "") -> None:
        super().__init__()
        self._api_key = api_key or settings.groq_api_key
        self.model = model or settings.groq_model

    def _key_env(self) -> str:
        return "VIRELLO_GROQ_API_KEY"

    def _model_env(self) -> str:
        return "VIRELLO_GROQ_MODEL"

    async def complete(self, req: AIRequest) -> AIResponse:
        client = self._client_or_raise(self._api_key)
        start = time.monotonic()
        body: dict = {
            "model": self.model,
            "temperature": req.temperature,
            "max_tokens": req.max_tokens,
            "messages": [
                {"role": "system", "content": req.system},
                {"role": "user", "content": req.user},
            ],
        }
        if req.json_mode:
            body["response_format"] = {"type": "json_object"}
        try:
            resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"authorization": f"Bearer {self._api_key}"},
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise AIProviderError(f"groq: {exc}") from exc
        choice = (data.get("choices") or [{}])[0]
        text = ((choice.get("message") or {}).get("content") or "")
        usage = data.get("usage", {})
        return AIResponse(
            text=text, provider=self.name, model=self.model,
            input_tokens=int(usage.get("prompt_tokens", 0)),
            output_tokens=int(usage.get("completion_tokens", 0)),
            latency_ms=int((time.monotonic() - start) * 1000),
        )


# ---------------------------------------------------------------------------
# Google (Gemini)
# ---------------------------------------------------------------------------
class GoogleProvider(_RestProvider):
    name = "google"

    def __init__(self, api_key: str = "", model: str = "") -> None:
        super().__init__()
        self._api_key = api_key or settings.google_api_key
        self.model = model or settings.google_model

    def _key_env(self) -> str:
        return "VIRELLO_GOOGLE_API_KEY"

    def _model_env(self) -> str:
        return "VIRELLO_GOOGLE_MODEL"

    async def complete(self, req: AIRequest) -> AIResponse:
        client = self._client_or_raise(self._api_key)
        start = time.monotonic()
        body = {
            "system_instruction": {"parts": [{"text": req.system}]},
            "contents": [{"parts": [{"text": req.user}]}],
            "generationConfig": {
                "temperature": req.temperature,
                "maxOutputTokens": req.max_tokens,
                "responseMimeType": "application/json" if req.json_mode else "text/plain",
            },
        }
        try:
            resp = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent",
                params={"key": self._api_key},
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise AIProviderError(f"google: {exc}") from exc
        cands = data.get("candidates", [])
        parts = ((cands[0].get("content") or {}).get("parts") or []) if cands else []
        text = "".join(p.get("text", "") for p in parts)
        meta = data.get("usageMetadata", {})
        return AIResponse(
            text=text, provider=self.name, model=self.model,
            input_tokens=int(meta.get("promptTokenCount", 0)),
            output_tokens=int(meta.get("candidatesTokenCount", 0)),
            latency_ms=int((time.monotonic() - start) * 1000),
        )


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------
class FallbackProvider(AIProvider):
    """Hafiz 2026-10-13: tries primary provider first, falls back to dev
    provider on failure (e.g. expired API key). Ensures AI features keep
    working even if the primary key expires."""

    name = "fallback"

    def __init__(self, primary: AIProvider, fallback: AIProvider) -> None:
        self._primary = primary
        self._fallback = fallback

    async def complete(self, req: AIRequest) -> AIResponse:
        try:
            return await self._primary.complete(req)
        except (AIProviderError, AIProviderNotConfigured) as exc:
            # Primary failed (expired key, quota, network) — use fallback.
            import logging
            logging.getLogger(__name__).warning(
                "Primary AI provider '%s' failed, using fallback: %s",
                self._primary.name, exc
            )
            return await self._fallback.complete(req)


def get_ai_provider(name: str = "") -> AIProvider:
    """Select the AI provider from configuration. Defaults to the dev
    (Muse environment) provider so local development needs no API keys.
    Hafiz 2026-10-13: Groq wraps with fallback to dev provider, so expiry
    (90 days) doesn't break AI features."""
    selected = (name or settings.ai_provider or "dev").lower()
    if selected == "anthropic":
        return AnthropicProvider()
    if selected == "openai":
        return OpenAIProvider()
    if selected == "google":
        return GoogleProvider()
    if selected == "groq":
        # Groq with automatic fallback to dev provider on failure/expiry.
        return FallbackProvider(GroqProvider(), DevMuseProvider())
    return DevMuseProvider()
