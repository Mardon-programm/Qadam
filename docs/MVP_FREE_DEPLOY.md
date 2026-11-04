# Qadam MVP free launch plan

## 1. Business rule for the first week

The project is configured for a free MVP launch:

- Drivers pay 0% commission by default.
- Passenger service fee is 0% by default.
- Prices are set to a competitive city-taxi level instead of a low-cost demo price.
- After 7 days, the team can move to a small paid driver plan or a small service fee.

This is the recommended production setup for the first week:

```env
DRIVER_COMMISSION_RATE=0.0
PASSENGER_SERVICE_FEE_RATE=0.0
MVP_FREE_DAYS=7
```

After the free trial:

```env
DRIVER_COMMISSION_RATE=0.08
PASSENGER_SERVICE_FEE_RATE=0.05
MVP_FREE_DAYS=0
```

This keeps the driver side attractive while allowing the platform to recover costs.

## 2. Deployment target

Use the cheapest viable stack without sacrificing product quality:

- Backend: Render
- Database: Neon Postgres
- Ops admin: Vercel
- Redis: Render or Railway (or free Redis add-on if available)

## 3. Required envs

```env
APP_ENV=production
SECRET_KEY=<32+ random chars>
DATABASE_URL=postgresql+asyncpg://<user>:<pass>@<host>/<db>
REDIS_URL=redis://<host>:6379/0
CORS_ORIGINS=https://<ops-domain>,https://<another-domain>,http://localhost:3000
SMS_PROVIDER=console
DRIVER_COMMISSION_RATE=0.0
PASSENGER_SERVICE_FEE_RATE=0.0
MVP_FREE_DAYS=7
```

## 4. Launch steps

1. Deploy backend to Render.
2. Create Neon Postgres database.
3. Run Alembic migrations.
4. Deploy Ops app to Vercel.
5. Set `NEXT_PUBLIC_API_URL` to the Render backend URL.
6. Test OTP login and order flow.
7. Register a test driver and a test passenger.
8. Confirm ride offer arrives in the driver app.
9. Accept the order and complete it through the end state.
10. After 7 days, switch monetization values.

## 5. Monetization after the first week

Recommended options:

- Driver plan: 99–199 som/month or 15–30 $/month
- Passenger service fee: 5% on trips
- Small subscription for active drivers only

This is a safer MVP than taxing every trip immediately.

## 6. Recommended pricing for launch

Keep the market price competitive:

- base fare: around 90–120
- per km: around 14–18
- per minute: around 2.5–3
- minimum fare: around 120–150

This is already close to premium city-taxi pricing and is better than a “cheap demo” pricing model.
