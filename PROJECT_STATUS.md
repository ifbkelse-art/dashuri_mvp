# Dashuri MVP: project status (2026-11-22)

**Working copy:** `~/Development/projects/dashuri_mvp`, with local git history of every step (`git log`).

**Original project:** `~/Development/projects/Dashuri` is unchanged. All 1,070 files were checked against a SHA-256 snapshot taken before the copy (`docs/mvp/original_snapshot.sha256`). Build output (`build/`, `.dart_tool/`, Gradle caches) was not copied; it regenerates.

**Founder decisions (21 Nov):**
- Diamonds are bought with **Google Play Billing by default**; **Cashfree** sits behind a flag.
- Video uses **Stream**.
- The product is the **host marketplace**, with the Free Call Card as random matching.
- Location is an **opt-in coarse city**.
- Chat goes through **Go + Supabase Realtime**.
- The UI follows the 19 Nov design handoff and is responsive.

Details and the API additions: `docs/mvp/MVP_DECISIONS_AND_CONTRACT.md`.

## Completed modules

| Module | Backend (Go + Postgres) | App (Flutter) |
|---|---|---|
| Authentication | Supabase JWT/JWKS verification; account provisioning; suspended/banned handling | Phone OTP (A03–A06); onboarding guard (A01–A15) |
| Profile | Profile, photos (upload tickets, moderation queue, delete), age gate, consents, levels | S01/S02, gender (private), photo picker |
| Discovery | Filters (language, city, sort), cursor paging, host detail, online count; block rules | C01–C09, C12; responsive grid |
| Matchmaking (Free Call Card) | Play Integrity, one card per phone and per device, 20/day host cap; ₹10 only for a full minute | C02, C10, V15 |
| Video call | Lifecycle, Stream tokens/webhooks, server metering, reservations, settlement, low balance, timeouts, history | Stream adapter, V01–V18, incoming-call watcher |
| Chat | Conversations, messages, read markers, privacy (past call partners), contact-detail filter | CH01–CH05; two-pane on tablets |
| Wallet | Ledger-backed summary and history | W01, W08, W09 |
| Payments | Play verify + server consume + RTDN + voided purchases; Cashfree orders, webhook (HMAC), poll; exactly-once credit | W02–W07; rail choice; Cashfree SDK |
| Location | Curated cities; nearest-city resolve; coordinates never stored | City picker (search / detect once) |
| Safety | Reports (24 h call window), grievances, blocks, enforcement, appeals; nudity checks in the first 3 min (Sightengine); moderator queue and decisions | Age gate, report/block (V11–V13), blocked users, account status + appeal, safety-check chip |
| Settings | Consents, messaging privacy, deletion (7-day grace + execution job), data export | S03–S10 |
| Host | Application, manual KYC (moderator decision), availability + heartbeat, rate (level caps), earnings, withdrawals (503 while payouts are off) | H01–H25 |
| Admin / finance | Reconciliation, dual-control adjustments (with conflict-of-interest checks), payout-cycle approval (disabled) | (no app UI, by design) |

Scheduled jobs (12):
- settle-stale-calls
- mark-offline-hosts
- moderation-missing-frames
- release-bean-holds
- poll-cashfree-orders
- expire-promo-diamonds
- reconcile-ledger
- poll-voided-purchases
- purge-expired-idempotency
- execute-account-deletions
- the remaining jobs listed by `go run ./cmd/worker`

## Partially complete (by design or blocked externally)

- **Payouts:** withdrawals are recorded, but payouts are off (`PAYOUTS_ENABLED=false`, founder R3-7). There is no payout-provider adapter, because no provider has been chosen.
- **KYC:** manual moderator review. A vendor adapter is needed later.
- **Push notifications:**
  - The server sends through FCM; the in-app inbox and Realtime work.
  - The app has no `firebase_messaging` yet, because that needs `google-services.json`.
- **Nudity checks:** frames are captured by each participant's own app (ADR-013), so a modified client could skip them; that is mitigated by the missing-frames review. Moving to server-side capture through Stream needs validation.
- **Legal texts** are drafts marked "pending legal review".
- **Product decisions still open** (D-03 … D-22) use reversible defaults, listed in the decisions doc.

## Tests executed (actual results, 2026-11-22)

| Suite | Command | Result |
|---|---|---|
| Format, analysis, dependency rules | `scripts/validate.sh` | Pass (no issues) |
| Dart/Flutter unit, bloc and widget tests (19 packages) | `melos run test` | **815 tests, all passed** |
| Go unit tests (race) | `go test -race ./...` | All packages pass |
| Go integration tests on real Postgres (as `api_service`) | `scripts/test-backend-integration.sh` | All packages pass |
| Migrations + 11 DB invariants | `scripts/validate-migrations.sh` | All pass |
| Android debug build | `flutter build apk --debug` | Built |
| Android release build (R8) | `flutter build apk --release` | Built (112 MB universal APK; upload an AAB) |

Integration tests cover, among others:
- an exact settlement: 65 s at 4,000 D/min → 4,333 Diamonds and 2,599 Beans;
- 50 parallel calls producing one live call;
- end and stale-call sweep racing, settled once;
- a Play purchase credited once across 10 concurrent verifications;
- a Cashfree webhook and poll racing, credited once;
- tampered and stale webhooks rejected;
- a refund reversing only unspent Diamonds;
- a moderation flag ending the call;
- a ban ending live calls;
- the free-call cap;
- the conflict-of-interest rules.

**Not tested:**
- End-to-end on a device against real Stream, Play, Cashfree and Supabase. This needs credentials.
- Flutter `integration_test` on an emulator.

## Security

An independent review found **no critical issues**. Fixed, with tests:
1. Customers could avoid billing by switching off their camera. Billing now depends on the host's video.
2. Minors and restricted accounts could buy Diamonds.
3. Enforcement did not end live calls.
5. Ledger adjustments could credit staff accounts.
6. Moderators could decide their own reports or act against staff.
7. Suspended and banned users could not appeal.
8. Moderation frames had no rate limit.
9. Webhook dedupe used an unsigned header.
10. Play purchases did not require the account binding.
11. Config defaulted to development.
12. Device tokens could reach the logs.

Also fixed: a ledger trigger that rejected valid debits; Play purchases were never consumed; the free-call payout rule.

**Residual risks:**
- **(4) Free Call device limit.** It relies on a Play-recognised app on a genuine device and a hash of `ANDROID_ID`; a factory reset gets a new card. Consider adding Play Integrity `deviceRecall`.
- **Contact details split across messages** get through, because the filter works per message.
- **Rate limits** are kept per instance.
- **Supabase email sign-up** is enabled in `config.toml`; production must allow phone sign-in only.
- **`api_service` can UPDATE `ledger.balances`.** It needs that for `SELECT … FOR UPDATE`; daily reconciliation detects drift.

## External credentials required

See `docs/mvp/INTEGRATION_CHECKLIST.md`.
- **Services:** Supabase (phone auth + SMS provider, JWKS, service keys), Stream, Google Play (products, service account, RTDN, Integrity), Sightengine, Firebase (push).
- **Cashfree:** keys, plus written category approval and a Play billing-policy decision.
- **Still to choose:** payout provider, KYC vendor.
- **Before release:** legal review, release signing key.

## Remaining production-readiness work

1. Configure real credentials in staging. Run the end-to-end path on devices: sign-in → buy (Play test track) → call → settle → wallet → host earnings.
2. Add `firebase_messaging` to the app, and Flutter `integration_test` flows in CI.
3. Set up CI (`scripts/validate.sh` + integration tests + an OpenAPI linter) and a Java 17 toolchain (see `docs/mvp/BUILD_AND_DEPLOY.md`).
4. Decide the open product items (D-03…D-22), payout provider and KYC vendor, and get legal and CA review.
5. Play Console: 18+, minor-blocking tools, data-safety form, Child Safety Standards, products. Upload an AAB.

**Docs:**
- Architecture: `docs/architecture/*`, ADR-011 (Cashfree), ADR-012 (city), ADR-013 (moderation frames)
- API: `api/openapi/dashuri.v1.yaml`, `docs/mvp/api/*.md`
- Build and deploy: `docs/mvp/BUILD_AND_DEPLOY.md`
