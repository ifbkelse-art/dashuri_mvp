# Dashuri backend (Go)

A modular monolith; see `docs/architecture/backend-architecture.md` and ADR-003.

```sh
cp .env.example .env      # local settings (git-ignored)
go run ./cmd/api          # :8080 — /healthz, /readyz, /v1/...
go run ./cmd/worker       # prints jobs and schedules
go test -race ./...
docker build -t dashuri-api .
```

## Status

| Implemented and tested | Contract scaffolded (returns 501) |
|---|---|
| `economy` rules and conversions; `ledger` model and entry templates; `calls` lifecycle and metering; idempotency middleware; problem+json errors; request id, recovery and access logging; config; rate limiter; route/auth coverage of the whole OpenAPI contract | All 60 endpoints' services; JWT verification (`auth.JWKSVerifier`); Postgres stores (`internal/adapters/postgres`); provider adapters (video, Play, payouts, KYC, moderation, push); worker jobs |

Every scaffolded service method lists the required implementation steps in comments. The source of truth for request and response shapes is `../api/openapi/dashuri.v1.yaml`; `dto.go` files mirror it.
