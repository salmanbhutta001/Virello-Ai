"""Vercel serverless entrypoint — lazy-loading wrapper.

ROOT CAUSE (proven 2026-10-28 via /__diag, deploy 10 dpl_Ah43s7q4):
the app import died at app/routers/uploads.py:34 — PROOF_DIR.mkdir()
on Vercel's READ-ONLY /var/task (app/static isn't even in the bundle),
OSError [Errno 30]. Every route 500'd. Fixed by making all import-time
mkdirs defensive (/tmp fallback) in uploads.py + curation/config.py.

This wrapper:
- imports app.main LAZILY on the first HTTP request, timed, with any
  exception captured instead of killing the function — a future import
  failure degrades to a JSON 500 naming the cause instead of a black
  box FUNCTION_INVOCATION_FAILED;
- answers the ASGI lifespan handshake ITSELF (startup.complete at
  once) and never forwards lifespan to the real app, so the real
  app's lifespan (init_db() DDL round-trips to Neon Singapore) does
  not run on Vercel cold start. The schema already exists in Neon
  from the restore, and the engine connects lazily per-request.

The /__diag probe that found the cause was REMOVED before this fix
shipped — it returned full tracebacks publicly.
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
