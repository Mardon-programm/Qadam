# Qadam Architecture — Stage 1

## Decision (locked)

- **First commercial slice:** City + Platform core.
- **Clients in parallel:** Backend + Ops + Flutter skeletons for critical flows.
- **Deferred full products:** Region booking UI/flows, Business portal depth (schema + module stubs only).
- **Payments:** one adapter interface + `mock` provider until a bank/PSP contract is signed.
- **Market:** Bishkek first.

## Shape

Modular monolith behind Nginx/API gateway. Horizontal scale via multiple app instances, external Redis/Postgres, workers for notifications and retries.

```
Flutter Passenger / Driver
Next.js Operations / Business
        │
   Nginx / TLS
        │
   FastAPI Application
   ├── Identity & Access
   ├── City Dispatch
   ├── Region Booking (stub)
   ├── Pricing
   ├── Payments + Ledger
   ├── Subscriptions
   ├── Trust & Safety
   ├── Notifications
   ├── Corporate (stub)
   ├── Support
   └── Reporting
        │
 PostgreSQL+PostGIS · Redis · Workers · OSRM
```

## Critical invariants

1. One city ride order cannot be assigned to two drivers.
2. Completed trip must not create a second ledger accrual.
3. Payment events are applied once (idempotency key).
4. Ledger entries are append-only (no silent edit/delete).
5. Driver cannot go online without approved documents + valid license status.
6. Operator financial/PII actions are audited.

## Module ownership

| Module | Owns |
|---|---|
| identity | users, sessions, OTP, roles |
| trust | documents, verification workflow, SOS cases |
| city | ride orders, dispatch, trip lifecycle |
| region | trips, seats, bookings (schema + stubs) |
| pricing | fare quote, surge caps |
| payments | payment intents, webhooks |
| ledger | immutable journal, wallet views |
| subscriptions | Flex / Pro plans |
| notifications | outbox + delivery workers |
| corporate | orgs, limits (stubs) |
| support | cases, complaints |
| ops | internal APIs for operators |
