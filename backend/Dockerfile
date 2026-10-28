# Virello API — production image (Railway-ready)
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv/virello

# ffmpeg: free server-side MP4 assembly for Creator Hub video tools
# (Ken Burns slideshow from AI/user photos — no paid video API needed).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-full.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY alembic.ini .
COPY alembic ./alembic
COPY app ./app

# Run migrations, seed community directory (idempotent), then start the API
CMD ["sh", "-c", "python -m alembic upgrade head && (python -m app.data.seed_communities_run || true) && (python -m app.data.seed_academy_run || true) && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8125} --workers 2"]
