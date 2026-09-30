"""Autonomous gallery publishing: push new gallery images to GitHub.

The hourly curation cycle builds product galleries into the gallery dir
(self-hosted JPGs). This module pushes any images that are not yet in the
repo to GitHub, so Railway auto-deploy serves them — with no Termux, phone,
or operator involvement.

Auth: VIRELLO_GITHUB_TOKEN (fine-grained PAT, Contents read+write).
Empty token -> graceful skip, never an error.

Safety:
- The token NEVER appears in logs, exceptions, or return values.
- Filename dedup: only JPGs whose names are absent from
  backend/app/static/gallery/ on main are committed (idempotent; safe
  alongside the operator-run cron flow which uses the same rule).
- One commit per call: "Gallery: <n> new angles (autonomous curation)".
- Every git failure is caught: a failed push NEVER fails the curation cycle.
- Sparse + blobless shallow clone: only ~12MB transferred, never the full
  gallery history.
"""
from __future__ import annotations

import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

log = logging.getLogger("virello.curation.git_push")

GALLERY_GIT_PATH = "backend/app/static/gallery"
COMMIT_USER_NAME = "Virello Curation"
COMMIT_USER_EMAIL = "curation@virello.local"
MASK = "***"

# Seconds per git step; the whole push should finish in ~1-2 minutes.
_GIT_TIMEOUT = 120


def _sanitize(text: str, token: str) -> str:
    """Remove every trace of the token (also URL-encoded forms)."""
    if not token or not text:
        return text
    import urllib.parse

    out = text.replace(token, MASK)
    out = out.replace(urllib.parse.quote(token, safe=""), MASK)
    return out


def _repo_url(repo: str, token: str = "") -> str:
    if token:
        return f"https://x-access-token:{token}@github.com/{repo}.git"
    return f"https://github.com/{repo}.git"


def _masked_repo_url(repo: str) -> str:
    return f"https://x-access-token:{MASK}@github.com/{repo}.git"


def _sh(args: list[str], cwd: str, token: str) -> subprocess.CompletedProcess:
    """Run a git command. Raises on failure with the token sanitized."""
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    try:
        return subprocess.run(
            args, cwd=cwd, env=env, capture_output=True, text=True,
            timeout=_GIT_TIMEOUT, check=True,
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            "git %s failed (exit %s): %s" % (
                args[1] if len(args) > 1 else args[0],
                e.returncode,
                _sanitize((e.stderr or e.stdout or "").strip()[:300], token),
            )
        ) from None
    except Exception as e:
        raise RuntimeError(
            "git %s error: %s" % (
                args[1] if len(args) > 1 else args[0],
                _sanitize(type(e).__name__, token),
            )
        ) from None


def _commit_message(n: int) -> str:
    return f"Gallery: {n} new angles (autonomous curation)"


def _existing_gallery_names(clone_dir: str, token: str) -> set[str]:
    """Filenames already in backend/app/static/gallery/ on main."""
    r = _sh(["git", "ls-tree", "-r", "--name-only", "HEAD", "--",
             GALLERY_GIT_PATH], cwd=clone_dir, token=token)
    prefix = GALLERY_GIT_PATH + "/"
    return {line[len(prefix):] for line in r.stdout.splitlines()
            if line.startswith(prefix)}


def _local_jpgs(gallery_dir: Path) -> list[Path]:
    if not gallery_dir.is_dir():
        return []
    return sorted(
        p for p in gallery_dir.iterdir()
        if p.is_file() and p.suffix.lower() in (".jpg", ".jpeg")
    )


def push_new_galleries(gallery_dir: str) -> dict:
    """Push gallery JPGs missing from GitHub main. Never raises.

    Returns {"pushed": bool, "new_files": int, "reason": str}.
    The token never appears in the result, logs, or exceptions.
    """
    from app.core.config import settings

    token = (settings.github_token or "").strip()
    repo = (settings.github_repo or "").strip()
    if not token:
        log.info("git push skipped: no token (set VIRELLO_GITHUB_TOKEN)")
        return {"pushed": False, "new_files": 0, "reason": "no_token"}
    if not repo or "/" not in repo:
        log.warning("git push skipped: bad repo %r", _sanitize(repo, token))
        return {"pushed": False, "new_files": 0, "reason": "bad_repo"}

    gdir = Path(gallery_dir)
    tmp = ""
    try:
        tmp = tempfile.mkdtemp(prefix="virello-gallery-push-")
        url = _repo_url(repo, token)
        log.info("cloning %s (sparse, blobless)", _masked_repo_url(repo))
        _sh(["git", "clone", "--depth", "1", "--branch", "main",
             "--filter=blob:none", "--no-checkout", "--quiet", url, tmp],
            cwd="/tmp", token=token)
        _sh(["git", "-C", tmp, "sparse-checkout", "set", "--no-cone",
             "/*", f"!{GALLERY_GIT_PATH}/"], cwd="/tmp", token=token)
        _sh(["git", "-C", tmp, "checkout", "--quiet"], cwd="/tmp", token=token)

        existing = _existing_gallery_names(tmp, token)
        new_files = [p for p in _local_jpgs(gdir)
                     if p.name not in existing]
        if not new_files:
            log.info("git push: nothing new (%d local, %d in repo)",
                     len(_local_jpgs(gdir)), len(existing))
            return {"pushed": False, "new_files": 0, "reason": "nothing_new"}

        dest = Path(tmp) / GALLERY_GIT_PATH
        dest.mkdir(parents=True, exist_ok=True)
        for p in new_files:
            shutil.copy2(p, dest / p.name)
        _sh(["git", "-C", tmp, "add", "--sparse", "--",
             *[f"{GALLERY_GIT_PATH}/{p.name}" for p in new_files]],
            cwd="/tmp", token=token)
        _sh(["git", "-C", tmp, "-c", f"user.name={COMMIT_USER_NAME}",
             "-c", f"user.email={COMMIT_USER_EMAIL}",
             "commit", "--quiet", "-m", _commit_message(len(new_files))],
            cwd="/tmp", token=token)
        _sh(["git", "-C", tmp, "push", "--quiet", "origin", "main"],
            cwd="/tmp", token=token)
        log.info("git push: %d new gallery images pushed to %s",
                 len(new_files), _sanitize(repo, token))
        return {"pushed": True, "new_files": len(new_files),
                "reason": "ok"}
    except Exception as e:
        # Sanitized: _sh already strips the token; belt-and-suspenders here.
        log.warning("git push failed: %s", _sanitize(str(e)[:200], token))
        return {"pushed": False, "new_files": 0,
                "reason": _sanitize(type(e).__name__, token)}
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)
