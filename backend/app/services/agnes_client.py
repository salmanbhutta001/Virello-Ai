"""Resilient Agnes AI API client with retry + circuit breaker.

Hafiz 2026-10-13: Creator Hub hardening — the AI Image and AI Video features
were failing intermittently with no retry logic and no protection against
cascading failures. This client provides:

- Retry with exponential backoff (1s, 2s, 4s) for transient failures
- Circuit breaker per service (image/video) — 5 consecutive failures opens
  the circuit for 60s, then half-open trial
- Request ID logging for debugging
- Separate timeouts per operation type

Do NOT retry on 400/401/403 (client errors) or 429 (rate limit — fail fast).
"""

import asyncio
import logging
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum

import httpx

log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

AGNES_BASE = "https://apihub.agnes-ai.com/v1"
AGNES_IMAGE_MODEL = "agnes-image-2.5-flash"
AGNES_VIDEO_MODEL = "agnes-video-v2.0"

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAYS = (1.0, 2.0, 4.0)  # seconds between attempts 1->2, 2->3, 3->4

# Circuit breaker configuration
CIRCUIT_FAILURE_THRESHOLD = 5  # consecutive failures before opening
CIRCUIT_OPEN_SECONDS = 60.0  # how long the circuit stays open

# HTTP status codes that are transient (safe to retry)
TRANSIENT_STATUS_CODES = frozenset({502, 503, 504})

# HTTP status codes that are fatal (never retry)
FATAL_STATUS_CODES = frozenset({400, 401, 403, 429})

# Timeouts (connect, read) per operation
IMAGE_TIMEOUT = httpx.Timeout(connect=10.0, read=120.0, write=10.0, pool=10.0)
VIDEO_SUBMIT_TIMEOUT = httpx.Timeout(connect=10.0, read=60.0, write=10.0, pool=10.0)
VIDEO_STATUS_TIMEOUT = httpx.Timeout(connect=10.0, read=30.0, write=10.0, pool=10.0)


# ---------------------------------------------------------------------------
# Error types
# ---------------------------------------------------------------------------


class AgnesError(Exception):
    """Base class for all Agnes API errors."""

    def __init__(self, message: str, request_id: str = ""):
        super().__init__(message)
        self.message = message
        self.request_id = request_id


class AgnesTransientError(AgnesError):
    """Retryable error — transient network/server issue."""


class AgnesFatalError(AgnesError):
    """Non-retryable error — bad request, auth failure, rate limit, etc."""


class AgnesCircuitOpenError(AgnesError):
    """Circuit breaker is open — failing fast to protect the service."""


class AgnesConfigError(AgnesError):
    """API key not configured on the server."""


# ---------------------------------------------------------------------------
# Circuit breaker
# ---------------------------------------------------------------------------


class _CircuitState(Enum):
    CLOSED = "closed"  # normal operation
    OPEN = "open"  # failing fast
    HALF_OPEN = "half_open"  # allowing one trial request


@dataclass
class _Circuit:
    """Per-service circuit breaker state."""

    state: _CircuitState = _CircuitState.CLOSED
    consecutive_failures: int = 0
    opened_at: float = 0.0
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)
    total_requests: int = 0
    total_failures: int = 0


# One circuit per service ("image", "video")
_circuits: dict[str, _Circuit] = {
    "image": _Circuit(),
    "video": _Circuit(),
}


def _get_circuit(service: str) -> _Circuit:
    """Get (or create) the circuit for a service."""
    if service not in _circuits:
        _circuits[service] = _Circuit()
    return _circuits[service]


async def _check_circuit(service: str, request_id: str) -> None:
    """Raise AgnesCircuitOpenError if the circuit is open.

    Transitions OPEN -> HALF_OPEN after the cooldown period.
    """
    circuit = _get_circuit(service)
    async with circuit.lock:
        if circuit.state == _CircuitState.OPEN:
            elapsed = time.monotonic() - circuit.opened_at
            if elapsed >= CIRCUIT_OPEN_SECONDS:
                circuit.state = _CircuitState.HALF_OPEN
                log.info(
                    "[%s] circuit %s: OPEN -> HALF_OPEN (cooldown expired)",
                    request_id, service,
                )
            else:
                remaining = int(CIRCUIT_OPEN_SECONDS - elapsed)
                raise AgnesCircuitOpenError(
                    f"Service temporarily unavailable — try again in "
                    f"{remaining}s.",
                    request_id=request_id,
                )
        # CLOSED and HALF_OPEN both allow the request through


async def _record_success(service: str, request_id: str) -> None:
    """Record a successful request — closes the circuit if half-open."""
    circuit = _get_circuit(service)
    async with circuit.lock:
        circuit.total_requests += 1
        if circuit.state == _CircuitState.HALF_OPEN:
            circuit.state = _CircuitState.CLOSED
            circuit.consecutive_failures = 0
            log.info(
                "[%s] circuit %s: HALF_OPEN -> CLOSED (trial succeeded)",
                request_id, service,
            )
        else:
            circuit.consecutive_failures = 0


async def _record_failure(service: str, request_id: str) -> None:
    """Record a failed request — opens the circuit at the threshold."""
    circuit = _get_circuit(service)
    async with circuit.lock:
        circuit.total_requests += 1
        circuit.total_failures += 1
        circuit.consecutive_failures += 1

        if circuit.state == _CircuitState.HALF_OPEN:
            # Trial failed — re-open
            circuit.state = _CircuitState.OPEN
            circuit.opened_at = time.monotonic()
            log.warning(
                "[%s] circuit %s: HALF_OPEN -> OPEN (trial failed)",
                request_id, service,
            )
        elif (
            circuit.state == _CircuitState.CLOSED
            and circuit.consecutive_failures >= CIRCUIT_FAILURE_THRESHOLD
        ):
            circuit.state = _CircuitState.OPEN
            circuit.opened_at = time.monotonic()
            log.warning(
                "[%s] circuit %s: CLOSED -> OPEN (%d consecutive failures)",
                request_id, service, circuit.consecutive_failures,
            )


def get_circuit_state(service: str) -> dict:
    """Return circuit breaker state for health checks.

    Args:
        service: "image" or "video"

    Returns:
        Dict with state, consecutive_failures, total_requests, total_failures.
    """
    circuit = _get_circuit(service)
    # Note: reading without lock is acceptable for monitoring (eventual consistency)
    state = circuit.state.value
    if circuit.state == _CircuitState.OPEN:
        elapsed = time.monotonic() - circuit.opened_at
        remaining = max(0, CIRCUIT_OPEN_SECONDS - elapsed)
    else:
        remaining = 0.0
    return {
        "service": service,
        "state": state,
        "consecutive_failures": circuit.consecutive_failures,
        "total_requests": circuit.total_requests,
        "total_failures": circuit.total_failures,
        "cooldown_remaining_sec": round(remaining, 1),
    }


def reset_circuit(service: str) -> None:
    """Manually reset a circuit (for tests / admin)."""
    circuit = _get_circuit(service)
    circuit.state = _CircuitState.CLOSED
    circuit.consecutive_failures = 0
    circuit.opened_at = 0.0


# ---------------------------------------------------------------------------
# API key
# ---------------------------------------------------------------------------


def _get_api_key() -> str:
    """Get the Agnes API key from settings."""
    from app.core.config import settings

    key = (settings.agnes_api_key or "").strip()
    if not key:
        raise AgnesConfigError(
            "AI service is not configured on the server yet. "
            "Please contact support."
        )
    return key


# ---------------------------------------------------------------------------
# Core retry logic
# ---------------------------------------------------------------------------


def _classify_http_error(status_code: int, body: str) -> AgnesError:
    """Classify an HTTP error response as transient or fatal."""
    if status_code == 429:
        return AgnesFatalError(
            "Service is busy right now — please try again in a minute."
        )
    if status_code == 401 or status_code == 403:
        return AgnesFatalError(
            "Service authentication failed — please contact support."
        )
    if status_code == 400:
        return AgnesFatalError(
            f"Invalid request: {body[:200]}"
        )
    if status_code in TRANSIENT_STATUS_CODES:
        return AgnesTransientError(
            f"Service returned HTTP {status_code} — will retry."
        )
    # Unknown 5xx or other — treat as transient (safe to retry)
    if 500 <= status_code < 600:
        return AgnesTransientError(
            f"Service returned HTTP {status_code} — will retry."
        )
    return AgnesFatalError(f"Unexpected HTTP {status_code}: {body[:200]}")


async def _execute_with_retry(
    service: str,
    request_id: str,
    operation: str,
    timeout: httpx.Timeout,
    method: str,
    url: str,
    **kwargs,
) -> httpx.Response:
    """Execute an HTTP request with retry + circuit breaker.

    Raises:
        AgnesCircuitOpenError: circuit is open (fail fast)
        AgnesFatalError: non-retryable error
        AgnesTransientError: retryable error, all retries exhausted
        AgnesConfigError: API key not configured
    """
    await _check_circuit(service, request_id)

    api_key = _get_api_key()
    headers = kwargs.pop("headers", {})
    headers["Authorization"] = f"Bearer {api_key}"

    last_error: AgnesError | None = None

    for attempt in range(MAX_RETRIES + 1):
        try:
            log.info(
                "[%s] %s %s attempt %d/%d",
                request_id, operation, method, attempt + 1, MAX_RETRIES + 1,
            )
            async with httpx.AsyncClient(timeout=timeout) as client:
                resp = await client.request(method, url, headers=headers, **kwargs)

            if 200 <= resp.status_code < 300:
                await _record_success(service, request_id)
                log.info(
                    "[%s] %s succeeded (HTTP %d)",
                    request_id, operation, resp.status_code,
                )
                return resp

            # Non-2xx — classify
            err = _classify_http_error(resp.status_code, resp.text)
            err.request_id = request_id

            if isinstance(err, AgnesFatalError):
                # Don't retry fatal errors, don't count toward circuit
                log.warning(
                    "[%s] %s fatal error (HTTP %d): %s",
                    request_id, operation, resp.status_code, err.message,
                )
                raise err

            # Transient — will retry
            last_error = err
            log.warning(
                "[%s] %s transient error (HTTP %d), attempt %d: %s",
                request_id, operation, resp.status_code, attempt + 1, err.message,
            )

        except httpx.RequestError as exc:
            # Network-level error (timeout, DNS, connection refused) — transient
            last_error = AgnesTransientError(
                f"Network error: {exc.__class__.__name__}",
                request_id=request_id,
            )
            log.warning(
                "[%s] %s network error, attempt %d: %s",
                request_id, operation, attempt + 1, exc,
            )
        except (AgnesFatalError, AgnesCircuitOpenError, AgnesConfigError):
            raise
        except AgnesTransientError as exc:
            last_error = exc
            # fall through to retry

        # Wait before retry (except after the last attempt)
        if attempt < MAX_RETRIES:
            delay = RETRY_DELAYS[attempt]
            log.info("[%s] retrying in %.1fs...", request_id, delay)
            await asyncio.sleep(delay)

    # All retries exhausted — record circuit failure
    await _record_failure(service, request_id)
    log.error(
        "[%s] %s failed after %d attempts: %s",
        request_id, operation, MAX_RETRIES + 1,
        last_error.message if last_error else "unknown",
    )
    raise last_error or AgnesTransientError(
        "Service unavailable after retries.", request_id=request_id
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


async def agnes_image_generate(
    prompt: str,
    style_suffix: str,
    seed: int | None,
    request_id: str = "",
) -> str:
    """Generate an image via Agnes AI.

    Args:
        prompt: User's image prompt
        style_suffix: Style descriptor appended to the prompt
        seed: Optional seed for regeneration
        request_id: Caller-provided ID for log correlation (auto-generated if empty)

    Returns:
        The image URL.

    Raises:
        AgnesConfigError: API key not configured
        AgnesCircuitOpenError: circuit breaker is open
        AgnesFatalError: bad request, auth failure, rate limit
        AgnesTransientError: service unavailable after retries
    """
    request_id = request_id or str(uuid.uuid4())[:8]
    full_prompt = f"{prompt}, {style_suffix}"

    log.info(
        "[%s] image_generate start (prompt_len=%d, seed=%s)",
        request_id, len(full_prompt), seed,
    )

    body: dict = {
        "model": AGNES_IMAGE_MODEL,
        "prompt": full_prompt,
        "n": 1,
        "size": "1024x1024",
    }
    # Agnes API requires seed in [-1, 999]. Clamp as safety net (mobile should already send valid seeds).
    if seed is not None:
        seed = max(-1, min(999, seed))
        body["seed"] = seed

    try:
        resp = await _execute_with_retry(
            service="image",
            request_id=request_id,
            operation="image_generate",
            timeout=IMAGE_TIMEOUT,
            method="POST",
            url=f"{AGNES_BASE}/images/generations",
            headers={"Content-Type": "application/json"},
            json=body,
        )
    except AgnesFatalError as e:
        # Map to user-friendly messages
        if "busy" in e.message.lower() or "429" in e.message:
            raise AgnesFatalError(
                "Image quota is busy right now — try again in a minute.",
                request_id=request_id,
            ) from e
        raise

    try:
        data = resp.json()
        url = data["data"][0]["url"]
    except (KeyError, IndexError, TypeError, ValueError) as e:
        await _record_failure("image", request_id)
        log.error("[%s] image_generate: invalid response format: %s", request_id, e)
        raise AgnesTransientError(
            "Image service returned invalid data.", request_id=request_id
        ) from e

    if not url:
        await _record_failure("image", request_id)
        raise AgnesTransientError(
            "Image service returned no image.", request_id=request_id
        )

    log.info("[%s] image_generate complete (url_len=%d)", request_id, len(url))
    return url


async def agnes_video_submit(
    prompt: str,
    duration_sec: int,
    aspect: str,
    request_id: str = "",
) -> dict:
    """Submit a text-to-video job to Agnes AI.

    Args:
        prompt: Video description prompt
        duration_sec: Desired duration in seconds
        aspect: Aspect ratio (e.g. "9:16")
        request_id: Caller-provided ID for log correlation

    Returns:
        Agnes response dict (contains video_id or id).

    Raises:
        AgnesConfigError, AgnesCircuitOpenError, AgnesFatalError,
        AgnesTransientError — as per agnes_image_generate.
    """
    request_id = request_id or str(uuid.uuid4())[:8]

    log.info(
        "[%s] video_submit start (duration=%ds, aspect=%s, prompt_len=%d)",
        request_id, duration_sec, aspect, len(prompt),
    )

    try:
        resp = await _execute_with_retry(
            service="video",
            request_id=request_id,
            operation="video_submit",
            timeout=VIDEO_SUBMIT_TIMEOUT,
            method="POST",
            url=f"{AGNES_BASE}/videos",
            headers={"Content-Type": "application/json"},
            json={
                "model": AGNES_VIDEO_MODEL,
                "prompt": prompt,
                "duration": duration_sec,
                "aspect": aspect,
            },
        )
    except AgnesFatalError as e:
        if "429" in e.message or "busy" in e.message.lower():
            raise AgnesFatalError(
                "Free video quota is busy right now — try again in a minute.",
                request_id=request_id,
            ) from e
        if "503" in e.message or "not configured" in e.message.lower():
            raise AgnesFatalError(
                "Online video is not configured on the server yet.",
                request_id=request_id,
            ) from e
        raise

    try:
        data = resp.json()
    except ValueError as e:
        await _record_failure("video", request_id)
        raise AgnesTransientError(
            "Video service returned invalid JSON.", request_id=request_id
        ) from e

    video_id = data.get("video_id") or data.get("id")
    if not video_id:
        # Some providers return the URL directly
        direct = data.get("video_url") or data.get("url")
        if direct:
            log.info("[%s] video_submit: direct URL returned", request_id)
            return {"video_url": direct}
        await _record_failure("video", request_id)
        raise AgnesTransientError(
            "Video service returned no job ID.", request_id=request_id
        )

    log.info("[%s] video_submit complete (video_id=%s)", request_id, video_id)
    return {"video_id": video_id, "raw": data}


async def agnes_video_status(
    video_id: str,
    request_id: str = "",
) -> dict:
    """Poll the status of an Agnes AI video job.

    Args:
        video_id: The Agnes video/job ID from agnes_video_submit
        request_id: Caller-provided ID for log correlation

    Returns:
        Status dict with at least a "status" key. Normalised states:
        "ready" (with "video_url"), "processing", "failed" (with "error").

    Raises:
        AgnesConfigError, AgnesCircuitOpenError, AgnesFatalError,
        AgnesTransientError — as per agnes_image_generate.
    """
    request_id = request_id or str(uuid.uuid4())[:8]

    log.debug("[%s] video_status poll (video_id=%s)", request_id, video_id)

    resp = await _execute_with_retry(
        service="video",
        request_id=request_id,
        operation="video_status",
        timeout=VIDEO_STATUS_TIMEOUT,
        method="GET",
        url=f"{AGNES_BASE}/agnesapi",
        params={"video_id": video_id},
    )

    try:
        data = resp.json()
    except ValueError as e:
        raise AgnesTransientError(
            "Video status returned invalid JSON.", request_id=request_id
        ) from e

    # Normalise provider-specific states
    raw_state = str(data.get("status", "")).lower()
    if raw_state in ("completed", "succeeded", "done", "ready"):
        video_url = data.get("video_url") or data.get("url") or data.get("video")
        return {"status": "ready", "video_url": video_url, "raw": data}
    if raw_state in ("failed", "error"):
        return {
            "status": "failed",
            "error": data.get("error", raw_state),
            "raw": data,
        }
    # Anything else → still processing (queued, running, etc.)
    # But also check for a direct URL (some providers complete inline)
    direct = data.get("video_url") or data.get("url")
    if direct:
        return {"status": "ready", "video_url": direct, "raw": data}
    return {"status": "processing", "raw": data}
