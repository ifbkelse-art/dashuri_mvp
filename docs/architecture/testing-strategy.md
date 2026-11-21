# Testing strategy

## Pyramid and what exists today

| Level | Tooling | Exists now | To add as features are built |
|---|---|---|---|
| Unit (Dart domain/core) | `package:test` | `dashuri_core` results, units, config; `dashuri_network` problem mapping, idempotency keys | Mapper tests per JSON model (contract drift) |
| BLoC | `bloc_test` + `mocktail` | Every feature's main cubit or bloc; `PurchaseBloc` idempotency reuse; `CallBloc` server-only billing | One test file per BLoC per user action |
| Widget | `flutter_test` | Theme smoke test | **Founder pages:** golden or widget tests per page state (loading, loaded, failed) |
| Repository (Dart) | `mocktail` on `ApiClient` or a fake HTTP adapter | — | Each repository: success, failure mapping, idempotency key passed through |
| Unit (Go domain) | `go test` | `economy` (conversion, rounding, rates, XP, levels, overflow); `ledger` (all templates balanced, cross-currency, keys); `calls` (metering, transitions); `idempotency` middleware | Service tests with fake ports |
| API (Go HTTP) | `httptest` | Every OpenAPI route mounted and auth-protected | Per-endpoint: validation 422s, role 403s, problem codes |
| Database integration | `scripts/validate-migrations.sh`; pgTAP via `supabase test db` | 11 invariants (balance, non-negative, immutability, exactly-once, one live call, rate bounds, client denial) | RLS tests per role; Realtime policy tests |
| Financial ledger | Go + real Postgres (testcontainers or local) | Template and DB invariants | See below |
| Concurrency | Go + real Postgres, parallel goroutines | — | See below |
| Security | Go tests + manual review | Unauthenticated access refused on all routes | JWT verification cases, IDOR tests, webhook signature tests, rate limits |
| End-to-end | `integration_test` (Flutter) on an emulator against staging | — | Sign-in → buy (Play test track, license testers) → call → settle → wallet |

## Financial test plan (must pass before real money)

1. **Conservation:** after any sequence of operations, Σ postings per currency = 0, and each balance equals the sum of its postings (property-based test with random operation sequences).
2. **Exactly-once:** replay every value-moving request and webhook N times, including concurrently; balances change once.
3. **Settlement:** table tests from metering timelines through to the expected Diamonds, Beans and residue. Example: 65 s at 4,000 D/min → 4,333 D → 2,599 Beans.
4. **Reversal:** a refund after partial spend removes only the unspent part, claws back held Beans, reverses XP, and never makes a balance negative.
5. **Holds and payouts:** Beans are not withdrawable before 7 days; the minimum is ₹500; a failed payout returns Beans; a cycle skips hosts with fraud cases.
6. **Promo expiry:** expired promotional Diamonds are removed; purchased Diamonds are never removed.
7. **Reconciliation:** inject a projection drift and confirm the job detects it.

## Concurrency test plan

- 50 parallel `POST /v1/calls` from one customer → exactly one live call and one reservation.
- Parallel settlement plus stale-call settlement for the same call → exactly one settlement.
- Parallel withdrawals totalling more than available → at most the available amount moves; the rest get `insufficient_available_beans`.
- Two free-call requests for the same card or device → one match; host counter never exceeds 20.
- Deadlock check: opposite-order operations on two accounts complete (ascending lock order plus retry).

## Commands

```sh
melos run test                  # Dart + Flutter
(cd backend && go test -race ./...)
./scripts/validate-migrations.sh
./scripts/validate.sh           # everything
```
