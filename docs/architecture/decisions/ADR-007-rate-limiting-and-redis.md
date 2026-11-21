# ADR-007: No Redis at launch; rate limiting in layers

- **Status:** Accepted, 2026-11-17

## Context
Redis is listed in the stack "where genuinely required". Candidate uses are rate limiting, presence and WebSocket fan-out.

## Decision
- Presence: host availability is a Postgres row with a heartbeat timestamp.
- Fan-out: Supabase Realtime (ADR-006).
- Idempotency and exactly-once: Postgres unique constraints.
- Rate limiting: a per-instance token bucket now; Cloud Armor rate rules at the edge and Postgres-backed counters for money- or safety-critical limits before scale.
- **No Redis at launch.**

## Trade-offs
Per-instance limits are approximate when Cloud Run scales out. Acceptable at launch volumes, mitigated by database constraints that hold regardless.

## Revisit when
Request rates make Postgres counters a hotspot, or a self-run WebSocket gateway is adopted. Then use Memorystore (Redis) for distributed limits and fan-out.
