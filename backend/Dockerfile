# Virello API — production image (Railway-ready, no apt-get)
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv/virello

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY alembic.ini .
COPY alembic ./alembic
COPY app ./app

# Run migrations, seed community directory (idempotent), then start the API
CMD ["sh", "-c", "python -m alembic upgrade head && (python -m app.data.seed_communities_run || true) && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8125} --workers 2"]
