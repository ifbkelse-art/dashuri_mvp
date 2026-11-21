# Database architecture (Supabase Postgres)

Migrations live in `supabase/migrations/` (Supabase CLI format) and are the only way the schema changes. They were validated on 2026-11-17 by `scripts/validate-migrations.sh`: all 6 apply and 11 database-enforced invariants pass.

## Schemas and ownership

| Schema | Owner module | Tables |
|---|---|---|
| `identity` | accounts | accounts, profiles, profile_photos, consents, data_requests |
| `economy` | economy | rule_sets (append-only), diamond_packages |
| `ledger` | ledger | accounts, balances, journal_entries, postings, diamond_reservations, xp_events, adjustment_proposals; view user_xp |
| `commerce` | purchases | purchases, play_notifications |
| `hosting` | hosts | hosts, kyc_sessions |
| `freecall` | freecall | cards, host_daily_counts |
| `calls` | calls | calls, media_events (append-only), settlements (append-only) |
| `chat` | chat | conversations, messages |
| `safety` | safety / moderation | blocks, reports, enforcement_actions, appeals |
| `moderation` | moderation | frame_checks, evidence |
| `payouts` | payouts | beneficiaries, cycles, withdrawals |
| `notify` | notifications | devices, inbox |
| `platform` | platform | idempotency_keys |
| `audit` | all (append) | events (append-only) |

The `public` schema holds no Dashuri data.

## Roles

| Role | Used by | Rights |
|---|---|---|
| `api_service` | Go API | DML on domain tables; **INSERT/SELECT only** on `ledger.*` and `audit.*` (plus UPDATE on balances, reservations, adjustment proposals); no DDL |
| `worker_service` | Cloud Run jobs | Same as `api_service` |
| `reporting_readonly` | Finance/CA exports | SELECT on ledger, commerce, payouts, economy |
| `anon`, `authenticated` | Mobile app via Supabase | **No grants on any domain schema** |
| `postgres` (owner) | Migrations only | DDL |

The migrations create the service roles as NOLOGIN. LOGIN and passwords are set per environment from Secret Manager. The Supabase **service-role key is not used by the Go API** and must never reach the app.

## Row Level Security

- RLS is enabled and **forced** on every domain table.
- One policy, `service_all`, grants the service roles access, and `reporting_read` grants finance read access. No policies exist for `anon` or `authenticated`, so access is denied by default even if a schema is accidentally exposed through PostgREST.
- Defense in depth: grants are revoked from client roles as well.

## What may use Supabase directly, and what must go through Go

| Operation | Path | Why |
|---|---|---|
| Phone OTP sign-in, token refresh, sign-out | **App → Supabase Auth** | Supabase is the identity provider |
| Receive server events (incoming call, call updates, new-message hints) | **App ← Supabase Realtime** private channels | Low latency without a custom WebSocket fleet (ADR-006). Read-only for clients. |
| Upload/read profile photos, evidence | **App ↔ Storage via signed URLs from Go** | Go decides who may upload and read; buckets are private |
| Profiles, discovery, chat, safety, settings | **Go** | Privacy rules, blocks, moderation, rate limits |
| Anything involving Diamonds, Beans, XP, calls, purchases, payouts | **Go only** | Financial integrity; server-authoritative |

## Realtime

- Server-to-client only. Go publishes broadcast messages to private topics `user:<uuid>` and `call:<uuid>`.
- The policy on `realtime.messages` lets an authenticated user **receive** only on their own user topic, and on call topics where `calls.is_participant()` (security definer) returns true.
- There is no INSERT policy, so clients cannot broadcast.
- Events are hints; clients re-fetch state from the API.

## Storage

Private buckets: `profile-photos`, `moderation-evidence`. Uploads use signed upload URLs from `POST /v1/me/photos/upload-tickets`, and photos stay unlisted until moderated. Evidence is written only by the backend, encrypted at rest (Supabase default), with access logged in `audit.events` and retention set by legal advice.

## Invariants enforced by the database

| Invariant | Mechanism |
|---|---|
| Every journal entry balances per currency, with ≥ 2 postings | Deferred constraint trigger `ledger.assert_entry_balanced` |
| Posting currency matches its account | Trigger `ledger.apply_posting` |
| User wallet balances never negative | `CHECK (not non_negative or balance >= 0)` on `ledger.balances` |
| Ledger, settlements, media events, rule sets, XP and audit are append-only | `platform.forbid_mutation` triggers + revoked UPDATE/DELETE |
| Each business event posts at most once | `UNIQUE (idempotency_key)` on journal entries |
| One settlement per call | PK on `calls.settlements(call_id)` |
| One live call per person | Partial unique indexes on `calls.calls` (caller and receiver) |
| One active Diamond reservation per user | Partial unique index |
| Purchase token credited once | `UNIQUE (purchase_token_hash)` |
| Paid call rate 500–10,000 D/min; host rate in range | CHECK constraints |
| Free calls ≤ 20 per host per day | CHECK on `freecall.host_daily_counts.count` |
| One Free Call Card per phone and per device | UNIQUE `phone_hash`, `device_binding_hash` |
| Manual adjustment needs two different people | CHECK `approved_by <> proposed_by` |

## Migration organisation

- One file per change, named `YYYYMMDDHHMMSS_description.sql`, forward-only. Fixes are new migrations.
- Apply locally with `supabase start && supabase db reset` (Docker), or quickly with `scripts/validate-migrations.sh` (plain Postgres plus stubs).
- Deploy with `supabase db push` to staging, then production, after review.
- Seed data: the founder rule set and the system ledger accounts are part of the migrations, because they are required.
