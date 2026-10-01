# Virello API — root Dockerfile for Railway (delegates to backend/)
# Railway auto-detects this at the repo root.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv/virello

COPY backend/requirements.txt .
# git: the autonomous curation cycle pushes new gallery images to GitHub
# itself (backend/app/curation/git_push.py); the slim image has no git.
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --upgrade pip && pip install -r requirements.txt

COPY backend/alembic.ini .
COPY backend/alembic ./alembic
COPY backend/app ./app

# Run migrations (must succeed: starting with a stale schema serves 500s),
# seed community directory (idempotent), then start the API
CMD ["sh", "-c", "python -m alembic upgrade head && (python -m app.data.seed_communities_run || true) && (python -m app.data.seed_academy_run || true) && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8125} --workers 2"]
