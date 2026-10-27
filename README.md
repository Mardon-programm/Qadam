# Qadam

Transport platform for Kyrgyzstan — city rides, intercity (Region), and corporate travel on one modular platform.

**First production slice:** Qadam City + Platform core (Identity, Trust, Payments Ledger, Operations).  
Region and Business are module boundaries in the monolith; full product surfaces come after City invariants are solid.

## Multilingual Support

Qadam supports two languages:
- **Russian (ru)** - primary language
- **Kyrgyz (ky)** - secondary language

Both passenger and driver apps include:
- Language selection screen on first launch
- Language switcher in profile settings
- Persistent language preference (saved locally)
- Comprehensive translations for all UI elements

## Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter (Passenger + Driver) |
| Web | Next.js (Operations / Business) |
| API | FastAPI modular monolith |
| DB | PostgreSQL + PostGIS |
| Cache | Redis |
| Maps | OSM + OSRM/Valhalla (ETA adapter) |
| Payments | Single provider adapter + mock sandbox |

## Repository layout

```
Qadam/
  backend/          FastAPI application
  apps/ops/         Next.js Operations console
  apps/passenger/   Flutter passenger app
  apps/driver/      Flutter driver app
  docs/             Architecture & business rules
  infra/            Nginx and deploy helpers
```

## Quick start (local)

```bash
cp .env.example .env
docker compose up -d postgres redis
cd backend && uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --reload --port 8000
```

API docs: http://localhost:8000/docs  
Health: http://localhost:8000/health

## Run everything in Docker

```bash
docker compose up -d
```

API (mapped to host port 8001): http://localhost:8001  
API docs: http://localhost:8001/docs  
Health: http://localhost:8001/health

Postgres is exposed on host port 5433, Redis on 6379.

Ops web (separate terminal):

```bash
cd apps/ops && npm install && npm run dev
```

## Production principles (from master spec)

- Do not sell an app — build a carrier network with transparent driver economics.
- License / document verification is a hard gate before a driver can go online.
- Financial records are append-only; payments are idempotent.
- Seat/order assignment is protected by DB transactions, not Redis alone.
- One payment route for v1; mock until a real partner contract exists.

## Launch market

Default city: **Bishkek**. Locales: `ru`, `ky`.

## Driver Commission

**Free for drivers** - The platform charges 0% commission to drivers, making it completely free for them to use. Passengers pay the full fare calculated based on distance, time, and traffic conditions.
