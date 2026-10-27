#!/bin/sh
# Container entrypoint: apply DB migrations, then start the API.
#
# Render starts the Docker image directly (no compose command), so migrations
# must run here. If they fail we still start the API and log the error so the
# service stays reachable (health check) while the problem is investigated.
set -e

echo "[start] applying database migrations"
if alembic upgrade head; then
    echo "[start] migrations applied"
else
    echo "[start] WARNING: migrations failed — starting the API anyway" >&2
fi

exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
