"""Shared test fixtures: create DB tables (httpx ASGI transport skips lifespan)."""
import pytest_asyncio

from app.core.database import init_db


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _init_tables():
    await init_db()
