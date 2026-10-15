"""AI image-generation provider layer (provider-agnostic, modular).

Mirrors the text AIProvider pattern in app/services/ai/base.py:
every image backend implements ImageProvider; the factory picks one from
configuration so providers can be swapped without rewrites.

Current implementation: Pollinations.ai (free, keyless, Flux-based).
It is an *optional* integration — the rest of the app never depends on it.
"""
from __future__ import annotations

import time
import urllib.parse
from abc import ABC, abstractmethod
from dataclasses import dataclass

import httpx

from app.core.config import settings


class ImageProviderError(Exception):
    """The image call failed (network, API error, bad response)."""


class ImageProviderNotConfigured(Exception):
    """No image provider is available. Fail closed."""


@dataclass
class ImageRequest:
    prompt: str
    width: int = 864
    height: int = 1080
    seed: int = 0  # 0 = random


@dataclass
class ImageResult:
    image_url: str          # direct URL to the generated image
    provider: str           # e.g. "pollinations"
    model: str              # e.g. "flux"
    width: int = 0
    height: int = 0
    latency_ms: int = 0


class ImageProvider(ABC):
    """Every image backend implements this."""

    name: str = "base"

    @abstractmethod
    async def generate(self, req: ImageRequest) -> ImageResult:
        ...


class PollinationsImageProvider(ImageProvider):
    """Free, keyless image generation via Pollinations.ai (Flux model).

    No credentials needed; output URLs are public. The provider is
    best-effort: failures raise ImageProviderError and the caller must
    surface an honest error (never a fake placeholder).
    """

    name = "pollinations"
    model = "flux"

    def __init__(self) -> None:
        self._client: httpx.AsyncClient | None = None

    def _client_or_new(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                timeout=httpx.Timeout(120.0, connect=15.0)
            )
        return self._client

    def _build_url(self, req: ImageRequest) -> str:
        prompt = urllib.parse.quote(req.prompt.strip()[:600])
        params = {
            "width": req.width,
            "height": req.height,
            "nologo": "true",
            "model": "flux",
        }
        if req.seed:
            params["seed"] = req.seed
        qs = urllib.parse.urlencode(params)
        return f"https://image.pollinations.ai/prompt/{prompt}?{qs}"

    async def generate(self, req: ImageRequest) -> ImageResult:
        if not req.prompt or not req.prompt.strip():
            raise ImageProviderError("empty prompt")
        url = self._build_url(req)
        client = self._client_or_new()
        start = time.monotonic()
        try:
            # HEAD-style verification: fetch headers only; the browser loads
            # the full bytes from the public URL.
            resp = await client.head(url, follow_redirects=True)
            ctype = resp.headers.get("content-type", "")
            if resp.status_code != 200 or "image" not in ctype:
                # Fall back to a ranged GET: some CDNs don't answer HEAD.
                r2 = await client.get(
                    url,
                    headers={"Range": "bytes=0-1023"},
                    follow_redirects=True,
                )
                ctype2 = r2.headers.get("content-type", "")
                if r2.status_code not in (200, 206) or "image" not in ctype2:
                    raise ImageProviderError(
                        f"pollinations: unexpected response "
                        f"({resp.status_code}/{r2.status_code})"
                    )
        except httpx.HTTPError as exc:
            raise ImageProviderError(f"pollinations: {exc}") from exc
        return ImageResult(
            image_url=url,
            provider=self.name,
            model=self.model,
            width=req.width,
            height=req.height,
            latency_ms=int((time.monotonic() - start) * 1000),
        )

    async def aclose(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None


def get_image_provider(name: str = "") -> ImageProvider:
    """Select the image provider from configuration.

    `VIRELLO_IMAGE_PROVIDER`: pollinations (default) | none.
    `none` disables generation entirely — endpoints fail closed.
    """
    selected = (name or getattr(settings, "image_provider", "pollinations") or "pollinations").lower()
    if selected == "none":
        raise ImageProviderNotConfigured(
            "image generation is disabled (VIRELLO_IMAGE_PROVIDER=none)"
        )
    return PollinationsImageProvider()
