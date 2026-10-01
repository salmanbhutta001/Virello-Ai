"""Cloudinary image store: credential parsing, signed uploads, disabled
state. Network calls are mocked — no real Cloudinary account is touched."""
from __future__ import annotations

import hashlib

import pytest

from app.core.config import settings
from app.curation import cloudinary_store as cs


def _set_url(monkeypatch, url: str):
    monkeypatch.setattr(settings, "cloudinary_url", url)


def test_disabled_when_empty(monkeypatch):
    _set_url(monkeypatch, "")
    assert cs.cloudinary_enabled() is False


def test_disabled_when_malformed(monkeypatch):
    for bad in ("not-a-url", "https://example.com/x",
                "cloudinary://onlykey@cloud", "cloudinary://:@cloud"):
        _set_url(monkeypatch, bad)
        assert cs.cloudinary_enabled() is False, bad


def test_enabled_when_valid(monkeypatch):
    _set_url(monkeypatch, "cloudinary://key123:sec456@mycloud")
    assert cs.cloudinary_enabled() is True


def test_sign_is_sha1_of_sorted_params_plus_secret():
    params = {"timestamp": "123", "public_id": "virello/gallery/B0X_main",
              "folder": "virello/gallery", "overwrite": "true"}
    body = "&".join(f"{k}={params[k]}" for k in sorted(params)) + "s3cr3t"
    assert cs._sign(params, "s3cr3t") == hashlib.sha1(body.encode()).hexdigest()


class _FakeResp:
    status_code = 200

    def json(self):
        return {"secure_url": "https://res.cloudinary.com/mycloud/image/"
                              "upload/v1/virello/gallery/B0X_main.jpg"}


class _FakeClient:
    def __init__(self, *a, **k):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    async def post(self, url, data=None, files=None):
        assert "api.cloudinary.com/v1_1/mycloud/image/upload" in url
        assert data["api_key"] == "key123"
        assert data["signature"] and len(data["signature"]) == 40
        assert data["public_id"] == "B0X_main"
        assert files["file"][2] == "image/jpeg"
        return _FakeResp()


@pytest.mark.asyncio
async def test_upload_image_returns_secure_url(monkeypatch):
    _set_url(monkeypatch, "cloudinary://key123:sec456@mycloud")
    monkeypatch.setattr(cs.httpx, "AsyncClient", _FakeClient)
    url = await cs.upload_image(b"\xff\xd8\xff" + b"0" * 100, "B0X_main")
    assert url.startswith("https://res.cloudinary.com/mycloud/")


@pytest.mark.asyncio
async def test_upload_image_raises_when_disabled(monkeypatch):
    _set_url(monkeypatch, "")
    with pytest.raises(RuntimeError, match="not configured"):
        await cs.upload_image(b"data", "B0X_main")


@pytest.mark.asyncio
async def test_upload_image_raises_on_http_error(monkeypatch):
    _set_url(monkeypatch, "cloudinary://key123:sec456@mycloud")

    class _BadResp:
        status_code = 401

    class _BadClient(_FakeClient):
        async def post(self, url, data=None, files=None):
            return _BadResp()

    monkeypatch.setattr(cs.httpx, "AsyncClient", _BadClient)
    with pytest.raises(RuntimeError, match="rejected"):
        await cs.upload_image(b"data", "B0X_main")


@pytest.mark.asyncio
async def test_delete_image_never_raises(monkeypatch):
    _set_url(monkeypatch, "")
    assert await cs.delete_image("whatever") is False
