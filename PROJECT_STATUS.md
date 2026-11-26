# Dashuri MVP: project status (2026-11-23)

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
| Host | Application, manual KYC (moderator decision), availability + heartbeat, rate (500 to level × 1,000; above 3,000 only for an active Verified Host), earnings, withdrawals (503 while payouts are off) | H01–H25; price selector with the Verified Host CTA; dashboard Pricing card |
| Verified Host (2026-11-23) | Separate premium status with a staff review workflow. Covers audit trail, private evidence bucket, purge job, price caps on revoke/suspend/level drop/call start, and DB CHECK. Discovery filter and ranking signal; `is_verified` on cards, call peer and chat peer | Badge everywhere a host appears; filter chips; application page (face video + ID). **Admin web app not built** (admin API only) |
| Admin / finance | Reconciliation, dual-control adjustments (with conflict-of-interest checks), payout-cycle approval (disabled) | (no app UI, by design) |

Scheduled jobs (13):
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
- purge-verification-evidence (2026-11-23)
- the remaining jobs listed by `go run ./cmd/worker`

## Verified Host and level pricing (2026-11-23)

Spec as built: `docs/mvp/VERIFIED_HOST_AND_PRICING.md`; decision: ADR-014; migration `20261123000300_verified_hosts_and_level_pricing.sql`.

**Test results (2026-11-23):**
- `scripts/validate.sh`: Dart format, analysis, dependency rules and all Flutter tests (21 packages, 1,259 tests) pass.
- Go format, vet, `go test -race ./...` and the build pass.
- Migrations and invariants pass: 17 invariants, 6 of them new.
- Integration on real Postgres: `scripts/test-backend-integration.sh -race ./...` passes in all 31 packages.

**Not yet applied to hosted environments.** The Supabase migration and the Cloud Run deploy wait for founder approval.

**Behaviour changes:**
- Existing prices above min(3,000, level × 1,000) are lowered by the migration, with audit rows.
- `is_verified` now means Verified Host, not KYC approved.

## Admin web console (2026-11-24)

`apps/admin` (React + Vite + TypeScript) is the staff console that replaces hand-run SQL. It covers:
- new-host activation, with the date of birth taken from the ID;
- Verified Host review, with private evidence through audited 5-minute links;
- photo review;
- reports, nudity flags and appeals;
- finance: reconciliation and two-person adjustments.

Access is by role (`admin`, `moderator`, `finance`), and the server enforces it again. Setup, role grants and deployment: `apps/admin/README.md`.

Backend additions, all additive:
- **CORS:** allowed only for the origins in `ADMIN_ORIGINS` (off when empty; the mobile app is unaffected).
- **Read-only staff views:** `GET /v1/admin/me`, `/users`, `/host-applications`, `/appeals`, `/ledger/adjustments`, `/audit`.
- **Reports:** `details` added to the moderation queue.

Tests:
- 28 console tests;
- 10 new Go unit tests (role matrix, CORS);
- one new Postgres integration test that runs as `api_service`.

Verified end to end against a local backend: approve and reject flows, the under-18 guard, the self-review and appeal-reviewer rules, and dual control. **Not deployed.** Firebase Hosting and a backend redeploy with `ADMIN_ORIGINS` are pending approval.

## Host Home online session, arrival photo and virtual gifts (2026-11-26, revised 27 Nov)

Built on `feat/calls-720p-and-app-icon`. **Uncommitted, not deployed.** The hosted migrations have not been applied. Everything new is behind flags that default to off; the online session on Host Home is client-only. The separate waiting room and its mini-games were removed on 27 Nov 2026.

| Feature | Backend | App | Flags (default off) |
|---|---|---|---|
| Host Home online session | Online sessions: a trigger on `hosts.is_available`; `online_session` on `GET /v1/host` | Host Home: `HostSessionBloc` (explicit states), online duration, notices after a call, network banner, tip, safety reminders. No waiting room, no mini-games. | — |
| Arrival photo | Private bucket. Ticket → upload → confirm (validate, re-encode, moderate). Expires on going offline. Purge job. Admin review. Discovery shows `arrival_photo`. Reports can reference it. | Optional prompt when going online (front camera only, preview, retake, skip). Card on Host Home. "Captured N minutes ago" on discovery cards and the profile, with Report photo. | `ARRIVAL_PHOTOS_ENABLED`, `DASHURI_ARRIVAL_PHOTOS_ENABLED`, `ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED` |
| Virtual gifts | `gifts` module. One atomic transaction: ledger `gift_send` + immutable gift + chat line. DB-level idempotency. Reservations protected. Admin catalogue with audited prices. Risk flags. | Gift control in place of camera-off (customer only), gift sheet, celebration queue/overlay (reduced motion, non-blocking), gift lines in chat, *Gifts sent* (wallet), *Gifts received* (host). | `GIFTS_ENABLED` (needs `CHAT_MESSAGE_CONTEXT_ENABLED`), `DASHURI_GIFTS_ENABLED` |

**Financial boundary.** Gifts use the current versioned rule set (16,670 D → 10,000 Beans) with no gift-specific commission. **The 5:4 model is NOT activated** (still modelling-only).

**Docs:**
- `docs/gifts/VIRTUAL_GIFTS.md`
- `docs/host/HOST_HOME_SESSION_AND_ARRIVAL_PHOTO.md`
- ADR-015
- the decision register (B-G1…B-G6)

**Migrations:** `20261126000100_host_online_sessions_and_arrival_photos.sql`, `20261126000200_virtual_gifts.sql`. Activation order: migrations → backend → app.

**Fix found during testing:** `postgres.AccountID` could fail with "no rows" when two transactions created the same ledger account concurrently. It now re-reads.

**Test results (2026-11-26):**
- Dart analysis (`--fatal-infos`): no issues. Dependency rules: OK.
- `melos run test`: 21 packages, **1,363 tests, all passed**.
- Go: `gofmt`, `go vet`, `go test -race ./...` and the build pass.
- Migrations: **32 invariants pass** (15 new).
- Go integration on real Postgres, as `api_service`, with `-race`: **all 35 packages pass**. That includes 13 new gift tests and 8 new arrival/session tests.
- Admin console: 32 tests pass; typecheck clean.
- `dart format --set-exit-if-changed` reports one file, `packages/features/purchases/test/data/purchases_data_test.dart`. It is unchanged from HEAD (pre-existing formatter drift), so it was left alone and `scripts/validate.sh` stops at its first step until that file is formatted.

**Open founder decisions:**
1. Activation.
2. Gift conversion: confirm "same as calls".
3. Whether promotional Diamonds can be gifted.
4. Gift limits.
5. Chargeback clawback of gift Beans.
6. Play policy review.
7. Sounds and artwork.
8. Arrival-photo moderation path and retention.
9. System camera vs an in-app camera plugin.

## Partially complete (by design or blocked externally)

- **Verified Host review UI:** no admin web app. Reviewers use the admin API (`/v1/admin/host-verifications`, `/v1/admin/hosts/{id}/verification/*`). Evidence retention (90 days) and the consent text need legal review.

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
