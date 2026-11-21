# Backend architecture (Go)

A **modular monolith** (ADR-003): one Go module (`backend/`), one container image, two binaries. The API runs as a Cloud Run service; scheduled jobs run as Cloud Run jobs. It is written against the standard library (`net/http` routing with method patterns, `log/slog`) plus `pgx` for Postgres.

```text
backend/
├── cmd/api/main.go            # HTTP server, graceful shutdown
├── cmd/worker/main.go         # `worker <job>`: scheduled, idempotent batch jobs
├── internal/
│   ├── app/                   # composition root: builds modules, mounts routes, health checks
│   ├── platform/              # shared plumbing, no business rules
│   │   ├── apperr/            # error kinds → HTTP mapping
│   │   ├── auth/              # JWT verification port, Principal, role middleware
│   │   ├── config/            # env config; secrets have no defaults
│   │   ├── db/                # pgx pool, TxManager (retries 40001/40P01)
│   │   ├── httpx/             # problem+json, JSON decode (64 KB cap, unknown fields rejected), middleware
│   │   ├── idempotency/       # Idempotency-Key middleware (+ tests)
│   │   ├── ratelimit/         # token bucket (per instance; see ADR-007)
│   │   ├── routing/           # middleware Stack passed to modules
│   │   ├── clock/, logging/
│   ├── adapters/postgres/     # Postgres implementations of platform ports (TODO bodies)
│   └── modules/
│       ├── economy/           # versioned business rules + conversions (implemented, tested)
│       ├── ledger/            # double-entry model, entry templates, Store port (implemented, tested)
│       ├── calls/             # lifecycle state machine + server metering (implemented, tested); API scaffold
│       ├── accounts/ levels/ discovery/ hosts/ payouts/ freecall/ chat/ wallet/
│       ├── purchases/ safety/ moderation/ notifications/ admin/
│       └── <module>/{module.go, dto.go, http.go, service.go, ports.go}
├── Dockerfile                 # distroless, non-root
└── .env.example
```

## Module anatomy

| File | Layer | Contents |
|---|---|---|
| `dto.go` | Transport contract | Request/response structs matching `api/openapi/dashuri.v1.yaml`; `validate()` on request types |
| `http.go` | Interface adapter | `Routes(mux, svc, stack)`: decode → validate → call service → encode. No business logic. |
| `service.go` | Application | One method per use case. Currently returns `apperr.NotImplemented`, with the required steps written as comments. |
| domain files (`lifecycle.go`, `metering.go`, `rules.go`, `ledger.go`, `templates.go`) | Domain | Pure logic with unit tests |
| `ports.go` | Domain ports | Interfaces for providers and repositories (`VideoProvider`, `PlayDeveloperAPI`, `PayoutProvider`, `NudityClassifier`, `KYCProvider`, `PushSender`, `ledger.Store`) |
| `module.go` | Wiring | `Deps` (ports the module needs), paging and validation helpers |
| `internal/adapters/<vendor>` | Infrastructure | Vendor SDK and Postgres implementations (only `postgres` exists, with TODO bodies) |

## Module boundaries

The brief's 18 candidates were consolidated to 14 HTTP modules plus 2 core libraries.

| Module | Owns (schema) | Notes |
|---|---|---|
| `accounts` | `identity.*` | Merges identity, users and profiles; age gate, consents, data requests |
| `levels` | reads `ledger.xp_events` | Shared account level |
| `discovery` | reads `hosting.hosts` | Available hosts; excludes blocks |
| `hosts` | `hosting.*` | Host application, KYC, availability heartbeat, rate (validated by `economy`) |
| `payouts` | `payouts.*` | Withdrawals, weekly cycles, provider-independent `PayoutProvider`; gated by `PAYOUTS_ENABLED` |
| `freecall` | `freecall.*` | Free Call Card (S4) |
| `calls` | `calls.*`, `ledger.diamond_reservations` | Lifecycle, provider webhooks, metering, settlement |
| `chat` | `chat.*` | Messaging privacy, blocks, filtering |
| `wallet` | reads `ledger.*` | Balances and history (read model). Merges wallet, diamond_transactions, bean_transactions. |
| `purchases` | `commerce.*` | Play verification, RTDN, voided purchases |
| `safety` | `safety.reports/blocks/appeals` | User-facing reporting and blocking |
| `moderation` | `moderation.*`, `safety.enforcement_actions` | Review queue, decisions, nudity checks, evidence |
| `notifications` | `notify.*` | Devices, inbox, push |
| `admin` | `ledger.adjustment_proposals`, reconciliation | Finance operations with dual control |
| `economy` (library) | `economy.*` | Rule sets |
| `ledger` (library) | `ledger.*` | The only code that builds journal entries |

`analytics` was not created: no analytics vendor or consent flow exists yet, and product analytics should not live in the transactional API. `reports` merged into `safety`; `administration` became `admin`.

**Ownership rule:** a module writes only its own schema. Cross-module effects (e.g. `calls` settling into `ledger`) go through `ledger.Store` and `ledger` templates, inside one database transaction managed by the calling service.

## Request pipeline

`Recover → RequestID → AccessLog → mux → [auth (JWT + roles from DB) → per-user rate limit] → [role check] → [Idempotency-Key] → handler`

Webhooks skip user auth and verify the provider signature or OIDC token in the service.

## API versioning

- Every path starts with `/v1`. Additive changes (new fields, new endpoints) stay in v1. Clients must ignore unknown response fields; the server rejects unknown request fields.
- Breaking changes need `/v2` routes, served alongside v1 until the minimum supported app version moves past them. Add a server-enforced minimum app version (`X-App-Version` header) before launch.

## Errors

Modules return `apperr` errors. `httpx.WriteError` maps them to RFC 9457 problem+json:

| Kind | Status |
|---|---|
| Validation | 422 |
| Unauthenticated | 401 |
| Forbidden | 403 |
| NotFound | 404 |
| Conflict / BusinessRule | 409 (`code: business_rule`, `rule: <name>`) |
| RateLimited | 429 |
| NotImplemented | 501 |
| Unavailable | 503 |
| Internal | 500, no detail; cause logged |

## Background jobs

Listed with schedules in `cmd/worker/main.go`:
- `release-bean-holds`
- `expire-promo-diamonds`
- `build-payout-cycle`
- `sync-payout-status`
- `reconcile-ledger`
- `poll-voided-purchases`
- `settle-stale-calls`
- `mark-offline-hosts`
- `purge-expired-idempotency`
- `retention-enforcement`

Every job is idempotent: it uses ledger idempotency keys and processes bounded batches with `FOR UPDATE SKIP LOCKED`.

## Logging

JSON `slog` with Cloud Logging field names. The access log records route pattern, status, latency and request id, never headers, bodies or query values. The forbidden-fields list is in `platform/logging`.
