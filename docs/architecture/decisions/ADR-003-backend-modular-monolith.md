# ADR-003: Go modular monolith on Cloud Run

- **Status:** Accepted, 2026-11-17

## Context
The initial production release has one developer, low-to-moderate traffic (simulation Base case: hundreds of paying customers by Month 6), and strong consistency needs. A call settlement touches calls, ledger, reservations and XP in **one transaction**.

## Decision
- One Go module and one image. `cmd/api` runs as a Cloud Run service; `cmd/worker` runs as Cloud Run jobs.
- Code is split into `internal/modules/*` with owned schemas and port interfaces; `internal/platform/*` holds plumbing; `internal/app` is the composition root.
- Standard-library HTTP (method routing), `slog`, `pgx`.

## Alternatives
- **Microservices** (wallet, calls, payouts…): cross-service transactions would need sagas or outbox patterns for every call settlement, plus more deploys, network failure modes and cost. No compelling reason at this scale.
- **Supabase Edge Functions only:** weaker fit for long-lived, transactional money logic and for the founder's Go preference.
- **A web framework (Gin, Echo):** unnecessary since Go 1.22 routing patterns.

## Trade-offs
One deploy unit means a bad release affects everything; mitigated by Cloud Run revisions and traffic rollback. Module discipline must be kept by review (no Go dependency checker yet).

## Future migration
Modules talk through ports and own their schemas, so one can be extracted later (e.g. payouts behind a queue) with an outbox table. Extract only for scaling or isolation needs that show up in measurements.
