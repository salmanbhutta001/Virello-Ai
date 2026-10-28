"""Vercel serverless entrypoint — re-exports the FastAPI app.

Vercel only auto-discovers Serverless Functions under api/, so the
FastAPI app (app/main.py) is exposed through this thin wrapper. The
`functions` pattern in vercel.json must match a file under api/ —
a pattern for app/main.py fails the build with `unused_function`.
"""
from app.main import app
