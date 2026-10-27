FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml README.md ./
COPY app ./app
COPY alembic.ini ./
COPY alembic ./alembic
COPY start.sh ./
RUN chmod +x start.sh

RUN pip install --no-cache-dir -U pip uv \
    && uv pip install --system -e ".[dev]"

EXPOSE 8000

CMD ["./start.sh"]
