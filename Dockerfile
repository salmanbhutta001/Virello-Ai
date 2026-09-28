# Virello API — root Dockerfile for Railway (delegates to backend/)
# Railway auto-detects this at the repo root.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv/virello

COPY backend/requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY backend/alembic.ini .
COPY backend/alembic ./alembic
COPY backend/app ./app

# Run migrations (tolerant: DB may already be migrated), seed community
# directory (idempotent), then start the API
CMD ["sh", "-c", "(python -m alembic upgrade head || echo 'alembic skipped/failed') && (python -m app.data.seed_communities_run || true) && (python -m app.data.seed_academy_run || true) && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8125} --workers 2"]
