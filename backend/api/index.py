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


async def _diagq_response(send):
    """TEMPORARY (2026-10-28): run the exact blog/products queries the
    live routes run, return per-query ok/error + traceback as JSON.
    Vercel MCP runtime logs are 403, so this is the only way to see the
    real DB error. REMOVE before the final deploy."""
    _try_import()
    if _state["app"] is None:
        await _send_json(send, 500, {"error": "app import failed",
                                     "detail": _state["error"]})
        return
    results = {}
    try:
        from sqlalchemy import func, select, text

        from app.blog.models import BlogPost
        from app.core.database import SessionLocal
        from app.models.commerce import Product

        async def _run(name, stmt):
            t0 = time.time()
            try:
                async with SessionLocal() as db:
                    res = await db.execute(stmt)
                    val = res.scalar() if "count" in name else len(res.scalars().all())
                results[name] = {"ok": True, "value": val,
                                 "seconds": round(time.time() - t0, 3)}
            except Exception as e:  # noqa: BLE001 - diagnostic
                results[name] = {"ok": False,
                                 "error": f"{type(e).__name__}: {e}",
                                 "traceback": traceback.format_exc(),
                                 "seconds": round(time.time() - t0, 3)}

        await _run("select_1", select(text("1")))
        await _run("blog_count",
                   select(func.count(BlogPost.id)).where(
                       BlogPost.status == "published"))
        await _run("blog_row",
                   select(BlogPost).where(
                       BlogPost.status == "published").limit(1))
        await _run("products_count",
                   select(func.count(Product.id)).where(
                       Product.is_active.is_(True)))
        await _run("products_row",
                   select(Product).where(
                       Product.is_active.is_(True)).limit(1))
    except Exception as e:  # noqa: BLE001 - diagnostic
        results["diag_error"] = {"error": f"{type(e).__name__}: {e}",
                                 "traceback": traceback.format_exc()}
    await _send_json(send, 200, results)


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
    if scope.get("path") == "/_diagq":
        await _diagq_response(send)
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
