"""Virello AI provider layer (provider-agnostic).

The AI Growth Agent talks only to the ``AIProvider`` interface defined here.
Which concrete model serves requests is chosen by configuration
(``VIRELLO_AI_PROVIDER``) — swapping providers never requires rewriting the app.

Providers:
  - ``dev`` (default): deterministic development/prototyping provider served by
    the available Muse AI environment. Responses are clearly labeled
    ``provider="dev"`` and carry ``"dev": true`` metadata — they exercise the
    full pipeline, honesty validation and auditing without any API key.
  - ``anthropic`` / ``openai`` / ``google``: real production APIs, used only
    when their API key (and model) is configured. Fail closed otherwise.

Every provider returns token usage so the Admin Dashboard can track AI spend.
"""
from .base import (
    AIProvider,
    AIProviderError,
    AIProviderNotConfigured,
    AIRequest,
    AIResponse,
    get_ai_provider,
)

__all__ = [
    "AIProvider",
    "AIProviderError",
    "AIProviderNotConfigured",
    "AIRequest",
    "AIResponse",
    "get_ai_provider",
]
