"""Test script for agnes_client.py — verifies retry + circuit breaker logic.

Run: cd ~/workspace/virello-app/backend && python3 -m pytest app/services/test_agnes_client.py -v
Or standalone: python3 app/services/test_agnes_client.py
"""

import asyncio
import sys
import os

# Ensure we can import the app module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from unittest.mock import AsyncMock, MagicMock, patch


async def test_retry_on_transient():
    """Transient 503 should be retried, then succeed."""
    from app.services import agnes_client
    from app.services.agnes_client import (
        agnes_image_generate, reset_circuit,
    )

    reset_circuit("image")

    # Mock: first two calls 503, third succeeds
    success_resp = MagicMock()
    success_resp.status_code = 200
    success_resp.json.return_value = {"data": [{"url": "https://example.com/img.jpg"}]}
    success_resp.text = ""

    fail_resp = MagicMock()
    fail_resp.status_code = 503
    fail_resp.text = "Service Unavailable"

    call_count = 0

    async def mock_request(method, url, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count <= 2:
            return fail_resp
        return success_resp

    with patch.object(agnes_client, "_get_api_key", return_value="test-key"):
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.__aexit__.return_value = None
        mock_client.request = mock_request

        with patch("httpx.AsyncClient", return_value=mock_client):
            # Patch sleep to avoid waiting in tests
            with patch("asyncio.sleep", new=AsyncMock()):
                url = await agnes_image_generate(
                    prompt="a cat", style_suffix="photorealistic",
                    seed=None, request_id="test-1",
                )

    assert url == "https://example.com/img.jpg", f"Got: {url}"
    assert call_count == 3, f"Expected 3 calls, got {call_count}"
    print("PASS: test_retry_on_transient (3 attempts, 2 retries)")


async def test_no_retry_on_429():
    """429 rate limit should fail fast with no retries."""
    from app.services import agnes_client
    from app.services.agnes_client import (
        agnes_image_generate, AgnesFatalError, reset_circuit,
    )

    reset_circuit("image")

    fail_resp = MagicMock()
    fail_resp.status_code = 429
    fail_resp.text = "Rate limit exceeded"

    call_count = 0

    async def mock_request(method, url, **kwargs):
        nonlocal call_count
        call_count += 1
        return fail_resp

    with patch.object(agnes_client, "_get_api_key", return_value="test-key"):
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.__aexit__.return_value = None
        mock_client.request = mock_request

        with patch("httpx.AsyncClient", return_value=mock_client):
            try:
                await agnes_image_generate(
                    prompt="a cat", style_suffix="photorealistic",
                    seed=None, request_id="test-2",
                )
                raise AssertionError("Should have raised AgnesFatalError")
            except AgnesFatalError as e:
                assert "busy" in e.message.lower() or "minute" in e.message.lower(), \
                    f"Unexpected message: {e.message}"

    assert call_count == 1, f"Expected 1 call (no retry), got {call_count}"
    print("PASS: test_no_retry_on_429 (fail fast, 1 attempt)")


async def test_no_retry_on_401():
    """401 auth failure should fail fast."""
    from app.services import agnes_client
    from app.services.agnes_client import (
        agnes_image_generate, AgnesFatalError, reset_circuit,
    )

    reset_circuit("image")

    fail_resp = MagicMock()
    fail_resp.status_code = 401
    fail_resp.text = "Unauthorized"

    call_count = 0

    async def mock_request(method, url, **kwargs):
        nonlocal call_count
        call_count += 1
        return fail_resp

    with patch.object(agnes_client, "_get_api_key", return_value="test-key"):
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.__aexit__.return_value = None
        mock_client.request = mock_request

        with patch("httpx.AsyncClient", return_value=mock_client):
            try:
                await agnes_image_generate(
                    prompt="a cat", style_suffix="photorealistic",
                    seed=None, request_id="test-3",
                )
                raise AssertionError("Should have raised AgnesFatalError")
            except AgnesFatalError:
                pass  # expected

    assert call_count == 1, f"Expected 1 call (no retry), got {call_count}"
    print("PASS: test_no_retry_on_401 (fail fast, 1 attempt)")


async def test_circuit_breaker_opens():
    """5 consecutive failures should open the circuit."""
    from app.services import agnes_client
    from app.services.agnes_client import (
        agnes_image_generate, AgnesTransientError, AgnesCircuitOpenError,
        get_circuit_state, reset_circuit,
    )

    reset_circuit("image")

    fail_resp = MagicMock()
    fail_resp.status_code = 503
    fail_resp.text = "Service Unavailable"

    async def mock_request(method, url, **kwargs):
        return fail_resp

    with patch.object(agnes_client, "_get_api_key", return_value="test-key"):
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.__aexit__.return_value = None
        mock_client.request = mock_request

        with patch("httpx.AsyncClient", return_value=mock_client):
            with patch("asyncio.sleep", new=AsyncMock()):
                # 5 failures to open the circuit
                for i in range(5):
                    try:
                        await agnes_image_generate(
                            prompt="test", style_suffix="style",
                            seed=None, request_id=f"cb-{i}",
                        )
                    except AgnesTransientError:
                        pass

                state = get_circuit_state("image")
                assert state["state"] == "open", f"Circuit not open: {state}"
                print(f"  Circuit state after 5 failures: {state['state']}")

                # 6th request should fail fast with circuit open
                try:
                    await agnes_image_generate(
                        prompt="test", style_suffix="style",
                        seed=None, request_id="cb-6",
                    )
                    raise AssertionError("Should have raised AgnesCircuitOpenError")
                except AgnesCircuitOpenError as e:
                    assert "temporarily unavailable" in e.message.lower(), \
                        f"Unexpected: {e.message}"

    print("PASS: test_circuit_breaker_opens (5 failures -> open, 6th fails fast)")


async def test_circuit_half_open_recovery():
    """After cooldown, a successful trial should close the circuit."""
    from app.services import agnes_client
    from app.services.agnes_client import (
        agnes_image_generate, AgnesTransientError,
        get_circuit_state, reset_circuit, _get_circuit,
    )

    reset_circuit("image")

    fail_resp = MagicMock()
    fail_resp.status_code = 503
    fail_resp.text = "Down"

    success_resp = MagicMock()
    success_resp.status_code = 200
    success_resp.json.return_value = {"data": [{"url": "https://example.com/ok.jpg"}]}
    success_resp.text = ""

    should_fail = True

    async def mock_request(method, url, **kwargs):
        if should_fail:
            return fail_resp
        return success_resp

    with patch.object(agnes_client, "_get_api_key", return_value="test-key"):
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.__aexit__.return_value = None
        mock_client.request = mock_request

        with patch("httpx.AsyncClient", return_value=mock_client):
            with patch("asyncio.sleep", new=AsyncMock()):
                # Open the circuit
                for i in range(5):
                    try:
                        await agnes_image_generate(
                            prompt="t", style_suffix="s",
                            seed=None, request_id=f"rec-{i}")
                    except AgnesTransientError:
                        pass

                assert get_circuit_state("image")["state"] == "open"

                # Simulate cooldown expiry by manually adjusting opened_at
                circuit = _get_circuit("image")
                import time
                async with circuit.lock:
                    circuit.opened_at = time.monotonic() - 61  # past 60s cooldown

                # Now the service recovers
                should_fail = False
                url = await agnes_image_generate(
                    prompt="t", style_suffix="s", seed=None, request_id="rec-trial")
                assert url == "https://example.com/ok.jpg"

                state = get_circuit_state("image")
                assert state["state"] == "closed", f"Not closed: {state}"

    print("PASS: test_circuit_half_open_recovery (trial succeeds -> closed)")


async def test_video_submit_and_status():
    """Video submit returns video_id; status normalises states."""
    from app.services import agnes_client
    from app.services.agnes_client import (
        agnes_video_submit, agnes_video_status, reset_circuit,
    )

    reset_circuit("video")

    submit_resp = MagicMock()
    submit_resp.status_code = 200
    submit_resp.json.return_value = {"video_id": "vid-123"}
    submit_resp.text = ""

    status_resp = MagicMock()
    status_resp.status_code = 200
    status_resp.json.return_value = {
        "status": "completed",
        "video_url": "https://example.com/vid.mp4",
    }
    status_resp.text = ""

    async def mock_request(method, url, **kwargs):
        if "agnesapi" in url:
            return status_resp
        return submit_resp

    with patch.object(agnes_client, "_get_api_key", return_value="test-key"):
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.__aexit__.return_value = None
        mock_client.request = mock_request

        with patch("httpx.AsyncClient", return_value=mock_client):
            result = await agnes_video_submit(
                prompt="a sunset", duration_sec=5, aspect="9:16",
                request_id="vid-test",
            )
            assert result["video_id"] == "vid-123", f"Got: {result}"

            status = await agnes_video_status("vid-123", request_id="vid-test")
            assert status["status"] == "ready", f"Got: {status}"
            assert status["video_url"] == "https://example.com/vid.mp4"

    print("PASS: test_video_submit_and_status (submit + normalised status)")


async def test_separate_circuits():
    """Image and video circuits are independent."""
    from app.services.agnes_client import (
        get_circuit_state, reset_circuit,
    )

    reset_circuit("image")
    reset_circuit("video")

    img = get_circuit_state("image")
    vid = get_circuit_state("video")
    assert img["service"] == "image"
    assert vid["service"] == "video"
    assert img["state"] == "closed"
    assert vid["state"] == "closed"
    print("PASS: test_separate_circuits (independent per-service)")


async def main():
    print("=" * 60)
    print("Agnes Client Tests — retry + circuit breaker")
    print("=" * 60)
    await test_retry_on_transient()
    await test_no_retry_on_429()
    await test_no_retry_on_401()
    await test_circuit_breaker_opens()
    await test_circuit_half_open_recovery()
    await test_video_submit_and_status()
    await test_separate_circuits()
    print("=" * 60)
    print("ALL TESTS PASSED")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
