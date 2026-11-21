# ADR-009: Supabase is identity, realtime and storage for the app — not its data API

- **Status:** Accepted, 2026-11-17

## Context
Supabase lets clients query tables directly through PostgREST under RLS. Dashuri's data is mostly money, calls, safety and privacy-sensitive relationships, where business rules (blocks, messaging privacy, eligibility, balances) are easy to get wrong in RLS and must be enforced together with ledger transactions.

## Decision
- The app uses Supabase for **Auth** (phone OTP), **Realtime** (receive-only private channels) and **Storage via signed URLs from Go**.
- Every domain read and write goes through the Go API.
- Domain schemas have RLS forced, no client grants and no client policies. The Go API uses a dedicated least-privilege role, not the service-role key.
- The service-role key never ships in the app.

## Alternatives
- **Direct client table access with RLS for non-financial data** (profiles, chat): less Go code, but splits enforcement of blocks and privacy across two systems.

## Trade-offs
More API endpoints to build. In exchange there is one enforcement point, simpler audits, and a contract-first API (OpenAPI).

## Future
A narrow, read-only exception (e.g. public host cards via a view) can be added later with explicit RLS tests if API load justifies it.
