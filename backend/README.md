# Qadam Backend

FastAPI modular monolith for City + Platform core.

```bash
uv sync
cp ../.env.example ../.env
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
uv run pytest
```
