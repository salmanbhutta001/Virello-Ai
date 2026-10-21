"""Image Studio robot: local rendering, sizes, Urdu shaping, job engine."""
from __future__ import annotations

import io
import uuid

import pytest
from PIL import Image
from sqlalchemy import select

import app.routers.create as create
import app.services.studio_robot as robot
from app.core.database import SessionLocal
from app.models.core import User
from app.models.image import ImageJob
from app.services.image_provider import LocalStudioProvider, get_image_provider


def _png_size(data: bytes) -> tuple[int, int]:
    with Image.open(io.BytesIO(data)) as im:
        assert im.format == "PNG"
        return im.size


# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("style", ["realistic", "cartoon", "3d"])
def test_render_each_style(style):
    data = robot.render_image("Grow with honest AI tips", style, 7, 1080, 1080)
    assert _png_size(data) == (1080, 1080)
    assert len(data) > 40_000  # a real design, not a blank canvas


def test_render_sizes():
    assert _png_size(robot.render_image("Hello", "realistic", 1, 1280, 720)) == (1280, 720)
    assert _png_size(robot.render_image("Hello", "realistic", 1, 1080, 1920)) == (1080, 1920)


def test_render_deterministic_per_seed():
    a = robot.render_image("Same prompt", "cartoon", 42, 600, 600)
    b = robot.render_image("Same prompt", "cartoon", 42, 600, 600)
    assert a == b
    c = robot.render_image("Same prompt", "cartoon", 43, 600, 600)
    assert a != c


def test_render_unknown_style_falls_back():
    data = robot.render_image("Hi there", "watercolor", 1, 500, 500)
    assert _png_size(data) == (500, 500)


def test_render_long_prompt_wraps():
    long_prompt = ("This is a very long prompt that keeps going with lots "
                   "of words about creating content and growing an audience "
                   "honestly every single day without shortcuts")
    data = robot.render_image(long_prompt, "realistic", 3, 1080, 1080)
    assert _png_size(data) == (1080, 1080)


def test_render_urdu_prompt():
    data = robot.render_image("اپنے کاروبار کو آن لائن بڑھائیں",
                              "realistic", 2, 1080, 1080)
    assert _png_size(data) == (1080, 1080)
    assert len(data) > 40_000
    # shaping machinery is present in this environment
    assert robot._raqm() is True
    assert robot._font_for("اپنے", bold_headline=True) == "urdu-bold.ttf"


def test_split_prompt():
    head, tail = robot._split_prompt("short text")
    assert tail == ""
    head, tail = robot._split_prompt("x " * 60)
    assert head and tail


# ---------------------------------------------------------------------------
# Provider factory
# ---------------------------------------------------------------------------

def test_factory_local_provider():
    p = get_image_provider("local")
    assert isinstance(p, LocalStudioProvider)
    assert p.name == "local-studio"


# ---------------------------------------------------------------------------
# Job pipeline: robot engine needs no Agnes key
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_image_job_runs_on_robot(monkeypatch):
    async def fake_upload(prompt, style="realistic", seed=0, **kw):
        return "https://res.cloudinary.com/test/studio.jpg"
    monkeypatch.setattr(robot, "generate_studio_image", fake_upload)
    monkeypatch.setattr(create, "_image_engine", lambda: "robot")

    async with SessionLocal() as db:
        user = User(email=f"studio-{uuid.uuid4().hex[:8]}@example.com",
                    name="Studio")
        db.add(user)
        await db.flush()
        job = ImageJob(id=uuid.uuid4().hex, user_id=user.id,
                       prompt="Grow with honest AI tips", style="cartoon",
                       seed=7, status="pending", request_id="test-req")
        db.add(job)
        await db.commit()
        job_id = job.id

    await create._process_image_job(job_id, "test-req")

    async with SessionLocal() as db:
        job = (await db.execute(select(ImageJob).where(
            ImageJob.id == job_id))).scalar_one()
        assert job.status == "ready"
        assert job.image_url == "https://res.cloudinary.com/test/studio.jpg"
