"""Autonomous gallery git-push: token gating, dedup, message format,
and the hard rule that the token never appears in logs or results."""
from __future__ import annotations

import logging
from pathlib import Path
from types import SimpleNamespace

import pytest

from app.curation import git_push
from app.curation.git_push import (
    _commit_message,
    _masked_repo_url,
    _repo_url,
    _sanitize,
    push_new_galleries,
)

FAKE_TOKEN = "ghp_FAKETOKEN1234567890"


@pytest.fixture
def gallery_dir(tmp_path):
    d = tmp_path / "gallery"
    d.mkdir()
    return d


def _jpg(d: Path, name: str) -> Path:
    p = d / name
    p.write_bytes(b"\xff\xd8\xff" + b"0" * 100)
    return p


def _subcmd(args):
    for x in args:
        if x in ("clone", "ls-tree", "add", "commit", "push", "checkout",
                 "sparse-checkout"):
            return x
    return ""


def _fake_sh_factory(ls_tree_stdout: str = "", fail_on: str = "",
                     fail_msg: str = ""):
    calls = []

    def fake_sh(args, cwd, token):
        calls.append((args, cwd))
        cmd = _subcmd(args)
        if fail_on and cmd == fail_on:
            raise RuntimeError(fail_msg or f"{cmd} exploded")
        if cmd == "clone":
            Path(args[-1]).mkdir(parents=True, exist_ok=True)
            return SimpleNamespace(stdout="", stderr="", returncode=0)
        if cmd == "ls-tree":
            return SimpleNamespace(stdout=ls_tree_stdout, stderr="",
                                    returncode=0)
        return SimpleNamespace(stdout="", stderr="", returncode=0)

    fake_sh.calls = calls
    return fake_sh


def _set_token(monkeypatch, token):
    monkeypatch.setattr("app.core.config.settings.github_token", token)


# ---------------------------------------------------------------------------
# 1. Token missing -> graceful skip, git never invoked
# ---------------------------------------------------------------------------

def test_no_token_skips_without_git(monkeypatch, gallery_dir, caplog):
    _set_token(monkeypatch, "")
    fake_sh = _fake_sh_factory()
    monkeypatch.setattr(git_push, "_sh", fake_sh)
    with caplog.at_level(logging.INFO, logger="virello.curation.git_push"):
        out = push_new_galleries(str(gallery_dir))
    assert out == {"pushed": False, "new_files": 0, "reason": "no_token"}
    assert fake_sh.calls == []
    assert "no token" in caplog.text


# ---------------------------------------------------------------------------
# 2. Filename dedup: only new JPGs are committed
# ---------------------------------------------------------------------------

def test_only_new_files_committed(monkeypatch, gallery_dir):
    _set_token(monkeypatch, FAKE_TOKEN)
    _jpg(gallery_dir, "EXIST1_angle1.jpg")   # already in repo
    _jpg(gallery_dir, "NEW99_angle1.jpg")    # missing -> push
    _jpg(gallery_dir, "NEW99_angle2.jpg")    # missing -> push
    (gallery_dir / "notes.txt").write_text("not an image")
    ls = ("backend/app/static/gallery/EXIST1_angle1.jpg\n"
          "backend/app/static/gallery/EXIST1_angle2.jpg\n")
    fake_sh = _fake_sh_factory(ls_tree_stdout=ls)
    monkeypatch.setattr(git_push, "_sh", fake_sh)

    out = push_new_galleries(str(gallery_dir))

    assert out["pushed"] is True
    assert out["new_files"] == 2
    assert out["reason"] == "ok"
    add_calls = [c for c in fake_sh.calls if _subcmd(c[0]) == "add"]
    assert len(add_calls) == 1
    added = add_calls[0][0]
    assert "backend/app/static/gallery/NEW99_angle1.jpg" in added
    assert "backend/app/static/gallery/NEW99_angle2.jpg" in added
    assert not any("EXIST1" in a for a in added)
    assert not any("notes.txt" in a for a in added)
    commit_calls = [c for c in fake_sh.calls if _subcmd(c[0]) == "commit"]
    assert commit_calls[0][0][-1] == "Gallery: 2 new angles (autonomous curation)"


def test_nothing_new_returns_early(monkeypatch, gallery_dir):
    _set_token(monkeypatch, FAKE_TOKEN)
    _jpg(gallery_dir, "EXIST1_angle1.jpg")
    ls = "backend/app/static/gallery/EXIST1_angle1.jpg\n"
    fake_sh = _fake_sh_factory(ls_tree_stdout=ls)
    monkeypatch.setattr(git_push, "_sh", fake_sh)

    out = push_new_galleries(str(gallery_dir))

    assert out == {"pushed": False, "new_files": 0, "reason": "nothing_new"}
    assert not any(_subcmd(c[0]) == "commit" for c in fake_sh.calls)
    assert not any(_subcmd(c[0]) == "push" for c in fake_sh.calls)


# ---------------------------------------------------------------------------
# 3. Commit message format
# ---------------------------------------------------------------------------

def test_commit_message_format():
    assert _commit_message(1) == "Gallery: 1 new angles (autonomous curation)"
    assert _commit_message(26) == "Gallery: 26 new angles (autonomous curation)"


# ---------------------------------------------------------------------------
# 4. Token never leaks: sanitize, masked URLs, failure paths
# ---------------------------------------------------------------------------

def test_sanitize_removes_token_and_encoded_form():
    import urllib.parse
    text = f"clone https://x-access-token:{FAKE_TOKEN}@github.com/r.git " \
           f"plus {urllib.parse.quote(FAKE_TOKEN, safe='')} tail"
    out = _sanitize(text, FAKE_TOKEN)
    assert FAKE_TOKEN not in out
    assert urllib.parse.quote(FAKE_TOKEN, safe="") not in out
    assert out.count("***") >= 2


def test_masked_url_has_no_token():
    assert FAKE_TOKEN not in _masked_repo_url("o/r")
    assert "***" in _masked_repo_url("o/r")
    # The authed URL is only ever passed to subprocess, never logged.
    assert FAKE_TOKEN in _repo_url("o/r", FAKE_TOKEN)


def test_token_never_in_logs_or_result_on_failure(
        monkeypatch, gallery_dir, caplog):
    _set_token(monkeypatch, FAKE_TOKEN)
    _jpg(gallery_dir, "NEW99_angle1.jpg")
    fake_sh = _fake_sh_factory(
        fail_on="push", fail_msg=f"denied for {FAKE_TOKEN} boom")
    monkeypatch.setattr(git_push, "_sh", fake_sh)
    with caplog.at_level(logging.INFO, logger="virello.curation.git_push"):
        out = push_new_galleries(str(gallery_dir))
    assert out["pushed"] is False
    assert FAKE_TOKEN not in str(out)
    assert FAKE_TOKEN not in caplog.text


def test_clone_failure_never_raises(monkeypatch, gallery_dir):
    _set_token(monkeypatch, FAKE_TOKEN)
    fake_sh = _fake_sh_factory(fail_on="clone", fail_msg="network down")
    monkeypatch.setattr(git_push, "_sh", fake_sh)
    out = push_new_galleries(str(gallery_dir))  # must not raise
    assert out["pushed"] is False
    assert out["reason"] == "RuntimeError"


def test_bad_repo_skipped(monkeypatch, gallery_dir):
    _set_token(monkeypatch, FAKE_TOKEN)
    monkeypatch.setattr("app.core.config.settings.github_repo", "notaslug")
    fake_sh = _fake_sh_factory()
    monkeypatch.setattr(git_push, "_sh", fake_sh)
    out = push_new_galleries(str(gallery_dir))
    assert out["reason"] == "bad_repo"
    assert fake_sh.calls == []
