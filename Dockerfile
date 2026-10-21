# Virello API — root Dockerfile for Railway (delegates to backend/)
# Railway auto-detects this at the repo root.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv/virello

COPY backend/requirements.txt .
# git: ops convenience only — product galleries live on Cloudinary now
# (the old git-push gallery flow was retired 2026-10-01).
# ffmpeg: free server-side MP4 assembly for Creator Hub video tools
# (Ken Burns slideshow from AI/user photos — no paid video API needed).
RUN apt-get update && apt-get install -y --no-install-recommends git \
    ffmpeg fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --upgrade pip && pip install -r requirements.txt

COPY backend/alembic.ini .
COPY backend/alembic ./alembic
COPY backend/app ./app

# Run migrations (tolerant: prod alembic chain has multiple roots and has
# never cleanly applied — init_db's create_all + ensure-columns own the
# prod schema; a hard alembic failure must not crash the service),
# seed community directory (idempotent), then start the API
CMD ["sh", "-c", "(python -m alembic upgrade head || echo 'alembic skipped/failed') && (python -m app.data.seed_communities_run || true) && (python -m app.data.seed_academy_run || true) && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8125} --workers 2"]
