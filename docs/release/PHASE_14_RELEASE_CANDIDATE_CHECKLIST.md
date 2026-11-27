# Phase 14: release-candidate checklist (second closed-testing update)

**Prepared 27 Nov 2026.** Nothing on this list has been released or uploaded. Every **[approval]** item needs an explicit founder decision before anyone acts on it.

**Status at preparation:** branch `feat/calls-720p-and-app-icon` at `54ff1e4` (version 0.1.0+4). Fix `8965dad` committed. Not pushed.

Legend: ☐ to do · ☑ done (with evidence) · ⚠ blocker.

## 1. Release prerequisites

| # | Item | Status | Evidence / note |
|---|---|---|---|
| 1.1 | All development phases committed in logical commits | ☑ | `e280429` … `54ff1e4` |
| 1.2 | Token-refresh fix reviewed and committed | ☑ | `8965dad` (founder-approved 27 Nov) |
| 1.3 | Branch pushed to GitHub **[approval]** | ☐ | Not pushed |
| 1.4 | Phase 13 device QA completed and signed off | ☐ | `docs/release/PHASE_13_PHYSICAL_DEVICE_QA.md` |
| 1.5 | Founder visual review of the Phase 9 screens | ☐ | Founder |

## 2. Engineering validation (latest verified runs)

| # | Check | Status | Evidence |
|---|---|---|---|
| 2.1 | `scripts/validate.sh`: Dart format, analysis, dependency rules, Flutter tests | ☑ | At `b95b654`: 21 packages, **1,467 tests** passed. App code unchanged after it except the uncommitted network fix (network package: 9 tests pass). |
| 2.2 | Go format, vet, `go test -race ./...`, build | ☑ | Same run (inside `validate.sh`) |
| 2.3 | Migrations + DB invariants | ☑ | Same run: 33 invariants pass |
| 2.4 | Go integration on real Postgres (`-race`, as `api_service`) | ☑ | 38 packages pass (Phases 6–11). Backend and migrations unchanged since `a62301c`. |
| 2.5 | Admin console tests + typecheck + build | ☑ | 40 tests, `tsc` clean, `vite build` ok after `867f6b8`. Admin unchanged since. |
| 2.6 | Android debug APK | ☑ | Built after Phase 9 |
| 2.7 | Android **release AAB** (signed with the upload key) | ☑ | 27 Nov: `app-release.aab` 94 MB, `jarsigner -verify` ok, signer CN=Balakumaaran Bharathiyar, O=BK ENTERPRISES |
| 2.8 | Merged manifest has no FOREGROUND_SERVICE_* permissions | ☑ | Checked on the release build |
| 2.9 | Re-run 2.1 after committing 1.2 and the version bump | ☑ | 27 Nov at `54ff1e4`: `scripts/validate.sh` passes. 21 packages, **1,468 Flutter tests**; Go format, vet, race tests and build; 33 invariants. |

## 3. Backend and environment (all **[approval]**: deploys and hosted changes)

The hosted dev backend (Cloud Run `dashuri-api` revision 00014) was built from `6d912f5` plus 7 fix files. **None of the later backend work is deployed:**
- wallet hints;
- consume retry;
- ledger payload check;
- price snapshot;
- self-review guards;
- production arrival guard;
- Reels claims;
- gifts;
- Verified Host.

| # | Item | Status | Note |
|---|---|---|---|
| 3.1 ⚠ | Decide the backend for this closed test: redeploy from a clean `HEAD` (never from a dirty tree) | ☐ | Without it, purchase recovery's consume-on-replay and the wallet hints don't work server-side. |
| 3.2 ⚠ | Apply hosted Supabase migrations **in order** (§3a) | ☐ | Needed before 3.1's code runs; dry run on a copy first. |
| 3.3 | Cloud Run env: `DASHURI_ENV`, `SUPABASE_JWT_ISSUER`, `PAYOUTS_ENABLED=false`, `GIFTS_ENABLED`, `ARRIVAL_PHOTOS_ENABLED`, `REELS_ENABLED=false`, `CHAT_MESSAGE_CONTEXT_ENABLED` decided | ☐ | `ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED` must be false in production (enforced). |
| 3.4 | `ADMIN_ORIGINS` and the admin console host (Firebase Hosting) if staff will moderate during the test | ☐ | |
| 3.5 | Play RTDN (Pub/Sub push) and the voided-purchases poll job configured on the dev project | ☐ | Needed for refund tests (PAY-09) |
| 3.6 | Production backend/config | ⚠ | `apps/mobile/config/production.json` is still a placeholder (`example.invalid`). A closed test on the dev backend is fine; a public release is not. |

### 3a. Hosted migrations not yet applied (order)

Verify against the hosted `supabase_migrations` table first.

1. `20261123000100_reels_experiment.sql`
2. `20261123000200_chat_message_context.sql`
3. `20261123000300_verified_hosts_and_level_pricing.sql`
4. `20261126000100_host_online_sessions_and_arrival_photos.sql`
5. `20261126000200_virtual_gifts.sql`
6. `20261127000100_reels_r2_media.sql`
7. `20261127000200_purchase_price_records.sql`
8. `20261127000300_gift_catalogue_names.sql`
9. `20261127000400_reels_processing_claims.sql`

## 4. Feature flags (app build defines + server env; must match)

| Flag (app / server) | Default | Recommended for this closed test | Note |
|---|---|---|---|
| `DASHURI_REELS_ENABLED` / `REELS_ENABLED` | off / off | **off** | R2 not configured |
| `DASHURI_GIFTS_ENABLED` / `GIFTS_ENABLED` | off / off | founder decision | Needs migrations 5 and 8, plus chat context on the server |
| `DASHURI_ARRIVAL_PHOTOS_ENABLED` / `ARRIVAL_PHOTOS_ENABLED` | off / off | founder decision | Needs migration 4; staff review queue in the admin console |
| `DASHURI_IN_CALL_CHAT_ENABLED` / `CHAT_MESSAGE_CONTEXT_ENABLED` | off / off | ⚠ **`config/phone.json` currently sets it TRUE** | Make sure the server flag matches, or turn it off in the build config |
| `DASHURI_PAYOUTS_ENABLED` / `PAYOUTS_ENABLED` | off / off | **off** | UI gate only; the server is authoritative |
| `DASHURI_CASHFREE_ENABLED` / `CASHFREE_ENABLED` | off / off | **off** | Cashfree rejected for production |

## 5. Versioning and release notes

| # | Item | Status |
|---|---|---|
| 5.1 | Bump `apps/mobile/pubspec.yaml` `version: 0.1.0+3` → `0.1.0+4` | ☑ `54ff1e4` (founder-approved) |
| 5.2 | Release notes for testers (draft below) | ☐ review |
| 5.3 | Tag the release commit locally (`rc-2`) after sign-off **[approval]** | ☐ |

**Draft tester release notes (≤ 500 characters):**
> Wallet now updates right away after purchases and calls; interrupted purchases are recovered automatically. Clearer error messages, easier-to-read call controls (Report and End call further apart), host earnings say clearly that withdrawals aren't open yet, and the call price is shown on the host profile. Many accessibility and small-screen fixes.

## 6. Build generation and signing (local only; no upload without approval)

```sh
cd apps/mobile
flutter build appbundle --release --dart-define-from-file=config/phone.json
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
```

| # | Item | Status |
|---|---|---|
| 6.1 | Built from a **clean checkout of the release commit** (`git status` empty apart from known untracked docs) | ☐ |
| 6.2 | Upload key present (`android/key.properties`, git-ignored); Play App Signing holds the app key | ☑ (verified 27 Nov) |
| 6.3 | `versionCode` in the merged manifest = the bumped value | ☑ Release AAB built 27 Nov from `54ff1e4`'s tree: versionCode 4, versionName 0.1.0; `jarsigner -verify` ok. Rebuild from a clean checkout of the final release commit before upload (6.1). |
| 6.4 | Upload to the **internal** track first, then the closed track **[approval]** | ☐ |

## 7. Payments validation (Play internal track, licence testers)

| # | Item | Status |
|---|---|---|
| 7.1 | PAY-01–PAY-08 pass on a device | ☐ |
| 7.2 | Refund via Play Console reverses only unspent Diamonds (PAY-09); RTDN delivered | ☐ |
| 7.3 | Ledger reconciliation job shows no drift after the tests (admin Finance → Reconciliation) | ☐ |
| 7.4 | No financial rule changed (16,670 D → 10,000 Beans; 200 Beans = ₹1; prices unchanged) | ☑ (no rule changes in any commit) |
| 7.5 | Chargeback recovery of host Beans: proposal only, **founder + CA decision** | ☐ |

## 8. Safety validation

| # | Item | Status |
|---|---|---|
| 8.1 | 18+ age gate refuses minors (AUTH-04); minors cannot buy | ☐ device |
| 8.2 | Report and block from profile, chat and call (DISC-07, CALL-11) | ☐ device |
| 8.3 | Staff cannot decide their own photo/arrival photo/verification/reel (`self_review`) | ☑ tests |
| 8.4 | Admin console roles enforced server-side (admin / moderator / finance) | ☑ tests |
| 8.5 | Contact-detail filter in chat (CHAT-02) | ☐ device |
| 8.6 | Nudity frame checks: Sightengine keys configured, or the human-review fallback staffed | ☐ |

## 9. Known issues (carry into the release notes or fix)

| Sev | Issue | Status |
|---|---|---|
| High | A failed session refresh (expired token + offline/revoked) escaped `ApiClient` as an exception, so screens could hang loading | **Fixed** `8965dad` (device check AUTH-07) |
| High | No push notifications: hosts must keep the app open to receive calls; customers get no message or offer pushes | Known limit (needs `google-services.json` + `firebase_messaging`) |
| Medium | Calls are not kept alive in the background (foreground services removed for Play policy) | Known limit |
| Medium | Hosted backend is behind the app (§3) | Founder decision |
| Medium | In-app legal texts are drafts (§10) | Founder decision |
| Low | Rate limits are per Cloud Run instance | Known |
| Low | Reels playback URLs expire after 6 h in a long-open feed | Reels off |
| Info | `READ_EXTERNAL_STORAGE` in the merged manifest (photo/video pickers): check the Data safety form | Check |
| Info | Supabase email sign-in is enabled in the local `config.toml`; make sure the hosted project allows phone only | Check |

## 10. Legal requirements

| # | Item | Status |
|---|---|---|
| 10.1 ⚠ | In-app Legal page: replace the "Draft — pending legal review … placeholders, not legally binding" banner and summaries, or link to the website v1.0 policies **[founder decision; no text invented]** | ☐ |
| 10.2 ⚠ | In-app Grievance Officer entry says "will be published here before launch"; the website names the officer | ☐ |
| 10.3 | Play Console links: privacy `/privacy/`, account deletion `/delete-account/`, Child Safety `/child-safety/` on dashuri.netlify.app | ☑ (published 25 Nov) |
| 10.4 | Website and app say the same thing (retention, deletion, billing) | ☐ after 10.1 |

## 11. Google Play requirements

| # | Item | Status |
|---|---|---|
| 11.1 | Content rating, target audience 18+, Data safety (re-check for camera / arrival photo / storage) | ☐ re-check |
| 11.2 | Closed-test tester list and licence testers | ☐ |
| 11.3 | Policy: "compensated arrangements" / dating-adjacent review risk | ☐ founder awareness |
| 11.4 | No foreground-service declaration needed (none in the manifest) | ☑ |

## 12. Rollback plan

- **App:** in Play Console, halt the closed-track rollout and promote the previous build (0.1.0+3) back. Keep its AAB (`apps/mobile/build/play/dashuri-0.1.0+3.aab`).
- **Backend:** Cloud Run "Manage traffic", 100% to the previous good revision (00014). **Never route to 00012/00013** (built from a dirty tree; broke refunds).
- **Migrations:** all Phase 1–11 migrations are additive. Rollback means stopping the new code; do **not** drop columns or tables with data.
- **Flags:** disable a misbehaving feature with its server flag (`GIFTS_ENABLED=false`, …). No app release is needed.

## 13. Release blocker tracker

| # | Blocker | Owner | Status |
|---|---|---|---|
| B1 | Physical-device QA (Phase 13) not run | Founder | Open |
| B2 | Backend redeploy + hosted migrations decision (§3) | Founder | Open |
| B3 | Version bump (§5.1) | Founder approval | **Done** `54ff1e4` |
| B4 | Legal page decision (§10.1–10.2) | Founder | Open |
| B5 | In-call chat flag consistency (`phone.json` TRUE) (§4) | Founder | Open |
| B6 | Commit the token-refresh fix (§1.2) | Founder approval | **Done** `8965dad` |
