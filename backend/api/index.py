"""Vercel serverless entrypoint — lazy-loading diagnostic wrapper.

Why this exists (2026-10-28): deploy 9 (834d1f0) is READY but every route
500s with FUNCTION_INVOCATION_FAILED in ~6s, deterministically. The
traceback is only in the dashboard runtime logs, which the Vercel MCP
tools cannot read (403). So this wrapper:

- imports app.main LAZILY on the first HTTP request, timed, with any
  exception captured (type + full traceback) instead of killing the
  function — /__diag reports it as JSON;
- answers the ASGI lifespan handshake ITSELF (startup.complete at
  once) and never forwards lifespan to the real app, so the real
  app's lifespan (init_db() DDL round-trips to Neon Singapore) does
  not run on Vercel cold start. The schema already exists in Neon
  from the restore, and the engine connects lazily per-request.

If diagnosis shows the lifespan was the killer, this wrapper (minus
/__diag) IS the fix. If the import itself fails, /__diag shows why.
"""

import json
import time
import traceback

_state = {
    "imported": False,
    "import_seconds": None,
    "error": None,
    "traceback": None,
    "app": None,
}


def _try_import():
    if _state["imported"] or _state["error"] is not None:
        return
    started = time.time()
    try:
        from app.main import app

        _state["app"] = app
        _state["imported"] = True
    except Exception as exc:  # noqa: BLE001 - diagnostic must capture anything
        _state["error"] = f"{type(exc).__name__}: {exc}"
        _state["traceback"] = traceback.format_exc()
    finally:
        _state["import_seconds"] = round(time.time() - started, 3)


async def _send_json(send, status, payload):
    body = json.dumps(payload).encode()
    await send(
        {
            "type": "http.response.start",
            "status": status,
            "headers": [[b"content-type", b"application/json"]],
        }
    )
    await send({"type": "http.response.body", "body": body})


async def _diag_response(send):
    _try_import()
    await _send_json(
        send,
        200,
        {
            "imported": _state["imported"],
            "import_seconds": _state["import_seconds"],
            "error": _state["error"],
            "traceback": _state["traceback"],
        },
    )


async def app(scope, receive, send):
    if scope["type"] == "lifespan":
        # Skip the real app's lifespan on Vercel (see module docstring).
        while True:
            message = await receive()
            if message["type"] == "lifespan.startup":
                await send({"type": "lifespan.startup.complete"})
            elif message["type"] == "lifespan.shutdown":
                await send({"type": "lifespan.shutdown.complete"})
                return
    if scope["type"] != "http":
        return
    if scope.get("path") == "/__diag":
        await _diag_response(send)
        return
    _try_import()
    real_app = _state["app"]
    if real_app is None:
        await _send_json(
            send,
            500,
            {
                "error": "app import failed",
                "detail": _state["error"],
                "traceback": _state["traceback"],
            },
        )
        return
    await real_app(scope, receive, send)
