# Qadam API

Production-ready transport platform for Kyrgyzstan.

## Project Status

✅ **Completed Components:**

### Backend (FastAPI)
- ✅ Identity & Authentication (OTP, JWT)
- ✅ City Rides (dispatch, matching, tracking)
- ✅ Region (intercity trips, seat booking)
- ✅ Trust & Safety (driver verification, documents)
- ✅ Payments & Ledger (transactions, wallet)
- ✅ Subscriptions (driver plans)
- ✅ Corporate (B2B accounts)
- ✅ Support System (cases, tickets)
- ✅ Operations Panel API
- ✅ Reporting & Analytics

### Mobile Apps (Flutter)
- ✅ Passenger App
  - ✅ Authentication (phone + OTP)
  - ✅ City rides (map, booking, tracking)
  - ✅ Region booking (search, details, confirmation)
  - ✅ Profile & Settings
  - ✅ Payment methods management
  - ✅ Ride history
  - ✅ Support tickets
  - ✅ Multilingual support (Russian, Kyrgyz)
  - ✅ Language selection on first launch
- ✅ Driver App
  - ✅ Authentication (phone + OTP)
  - ✅ Dashboard with online status
  - ✅ Order management
  - ✅ Profile & Settings
  - ✅ Multilingual support (Russian, Kyrgyz)
  - ✅ Language selection on first launch
  - ✅ Free for drivers (0% commission)

### Web Dashboards (Next.js)
- ✅ Operations Console
  - ✅ Driver management & verification
  - ✅ Document review workflow
  - ✅ Rides monitoring
  - ✅ Bookings overview
  - ✅ Support cases management
  - ✅ Financial reports
  - ✅ Audit log viewer
  - ✅ Platform statistics

### Infrastructure
- ✅ Docker Compose for local development
- ✅ Production Docker Compose setup
- ✅ Nginx reverse proxy with rate limiting
- ✅ PostgreSQL + PostGIS for spatial data
- ✅ Redis for caching and sessions
- ✅ Prometheus monitoring configuration
- ✅ Grafana dashboards
- ✅ Alert rules for critical metrics
- ✅ Automated backup scripts
- ✅ Deployment automation
- ✅ Health check scripts
- ✅ Production runbook

## Quick Start

### Local Development

```bash
# 1. Setup environment
cp .env.example .env
# Edit .env with your local settings

# 2. Start infrastructure
docker compose up -d postgres redis

# 3. Run migrations
cd backend
uv sync
uv run alembic upgrade head

# 4. Start API
uv run uvicorn app.main:app --reload --port 8000

# 5. Start Ops Web (in another terminal)
cd apps/ops
npm install
npm run dev

# 6. Run Passenger App (in another terminal)
cd apps/passenger
flutter pub get
flutter run
```

### Production Deployment

See detailed guide in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

```bash
# Quick production deploy
./infra/deploy.sh production

# Health check
./infra/health-check.sh

# Database backup
./infra/backup-db.sh
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│  Passenger App  │     │   Driver App    │
│    (Flutter)    │     │    (Flutter)    │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │    Nginx (Gateway)    │
         │  Rate Limit + SSL     │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐     ┌─────────────┐
         │   FastAPI Backend     │────▶│   Redis     │
         │  (Modular Monolith)   │     │   Cache     │
         └───────────┬───────────┘     └─────────────┘
                     │
         ┌───────────▼───────────┐     ┌─────────────┐
         │  PostgreSQL + PostGIS │     │  Worker     │
         │   (Primary Store)     │◀────│   Queue     │
         └───────────────────────┘     └─────────────┘

         ┌─────────────────────────────────────┐
         │         Monitoring Stack            │
         │  Prometheus + Grafana + Alerts      │
         └─────────────────────────────────────┘
```

## API Documentation

When running locally with `APP_ENV=development`:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- OpenAPI JSON: http://localhost:8000/openapi.json

**Note**: API docs are disabled in production for security.

## Key Features

### For Passengers
- 🚗 City rides with real-time tracking
- 🚌 Intercity trip booking with seat selection
- 💳 Multiple payment methods
- 📱 Push notifications for ride updates
- ⭐ Driver ratings and reviews
- 🎫 Digital ride receipts
- 🆘 Emergency support button

### For Drivers
- 📋 Document verification workflow
- 💰 Transparent earnings dashboard
- 📊 Performance metrics and rating
- 🎯 Smart ride matching
- 💳 Flexible payment plans (commission vs subscription)
- 🚗 Vehicle management
- 📞 In-app support

### For Operations Team
- 👥 User and driver management
- ✅ Document review and verification
- 📊 Real-time platform statistics
- 💵 Financial reporting
- 🎫 Support ticket management
- 🔍 Audit log for compliance
- 📈 Business analytics

### For Corporate Clients
- 🏢 Multi-user account management
- 💼 Role-based access control
- 💰 Budget limits and approvals
- 📊 Expense reporting
- 📄 Automated invoicing
- 🎯 Dedicated support

## Technology Stack

### Backend
- **Framework**: FastAPI 0.109+
- **Language**: Python 3.12+
- **Database**: PostgreSQL 16 + PostGIS
- **Cache**: Redis 7
- **ORM**: SQLAlchemy 2.x
- **Migrations**: Alembic
- **Auth**: JWT with refresh tokens
- **Validation**: Pydantic v2
- **Async**: asyncio + asyncpg

### Mobile
- **Framework**: Flutter 3.x
- **Language**: Dart
- **State**: Riverpod
- **Routing**: go_router
- **HTTP**: Dio
- **Storage**: shared_preferences

### Web
- **Framework**: Next.js 14
- **Language**: TypeScript
- **UI**: Tailwind CSS
- **HTTP**: Axios
- **State**: SWR
- **Charts**: Recharts

### DevOps
- **Containers**: Docker + Docker Compose
- **Proxy**: Nginx
- **Monitoring**: Prometheus + Grafana
- **Logs**: Docker logs → centralized
- **CI/CD**: GitHub Actions (ready for setup)

## Security Features

- 🔐 JWT-based authentication with refresh tokens
- 📱 OTP verification for phone numbers
- 🔒 Bcrypt password hashing (for future password auth)
- 🚫 Rate limiting on auth endpoints
- 🛡️ SQL injection protection via ORM
- 🔍 Audit logging for sensitive operations
- 🔐 HTTPS/TLS in production
- 🚨 Security headers (X-Frame-Options, CSP, etc.)
- 🔑 Environment-based secrets management
- 👤 Role-based access control (RBAC)

## Performance

### Targets
- API response time: p95 < 500ms
- Database queries: < 100ms
- Cache hit rate: > 80%
- API error rate: < 1%
- Uptime: > 99.5%

### Optimizations
- Database connection pooling
- Redis caching for hot data
- Async I/O throughout
- Database indexes on frequent queries
- API request/response compression
- Rate limiting to prevent abuse
- Horizontal scaling ready (stateless API)

## Testing

```bash
# Run backend tests
cd backend
uv run pytest

# Run with coverage
uv run pytest --cov=app --cov-report=html

# Run specific test
uv run pytest tests/test_city.py -v
```

## Environment Variables

Key variables (see `.env.example` for full list):

```env
# App
APP_ENV=development|production
SECRET_KEY=<random-key>

# Database
DATABASE_URL=postgresql+asyncpg://user:pass@host/db

# Redis
REDIS_URL=redis://host:6379/0

# JWT
JWT_SECRET_KEY=<random-key>
ACCESS_TOKEN_EXPIRE_MINUTES=60

# External Services
SMS_PROVIDER=<provider>
PAYMENT_PROVIDER=<provider>
OSRM_URL=http://localhost:5000
```

## Contributing

1. Create feature branch from `main`
2. Make changes with tests
3. Run linting: `ruff check app/`
4. Run tests: `pytest`
5. Create pull request
6. Wait for CI checks and review

## Deployment Checklist

Before production launch:

- [ ] All environment variables configured
- [ ] Database migrations tested
- [ ] SSL certificates installed
- [ ] Backup automation enabled
- [ ] Monitoring alerts configured
- [ ] Payment provider integrated
- [ ] SMS provider integrated
- [ ] Firewall rules configured
- [ ] Domain DNS configured
- [ ] Load testing completed
- [ ] Security audit completed
- [ ] Documentation reviewed
- [ ] Support team trained
- [ ] Rollback plan documented

## Monitoring & Alerts

### Dashboards
- **Grafana**: http://localhost:3000
  - Platform Overview
  - API Performance
  - Database Metrics
  - Business KPIs

### Alerts (Prometheus)
- API down (critical)
- High error rate (critical)
- Database connection issues (critical)
- No drivers online (warning)
- Payment failures (warning)
- Disk space low (critical)

## Support & Documentation

- 📖 [Architecture Spec](docs/docs.md)
- 🚀 [Deployment Guide](docs/DEPLOYMENT.md)
- 📋 [Production Runbook](docs/RUNBOOK.md)
- 🐛 [Issue Tracker](https://github.com/your-org/qadam/issues)

## License

Proprietary - Qadam Platform © 2026

## Team

- Platform Lead: [name]
- Backend Team: [names]
- Mobile Team: [names]
- DevOps: [name]
- Product: [name]

---

Built with ❤️ for Kyrgyzstan's transportation future.
