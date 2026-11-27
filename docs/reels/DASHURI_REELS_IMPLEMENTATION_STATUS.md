# Dashuri Reels — implementation status (EXPERIMENT, 22 Nov 2026)

## 00. Update 27 Nov 2026 — Mux being replaced by Cloudflare R2

The founder decided to remove recurring Mux cost. New uploads now target
Cloudflare R2 + our own ffmpeg processing (`REELS_VIDEO_PROVIDER=r2`,
default); Mux stays only as a transitional legacy provider. Built and
tested locally, no account, nothing deployed. Full design, cost, test
results and the list of remaining Mux dependencies:
`docs/reels/DASHURI_REELS_R2_MIGRATION.md`. Sections below that say "Mux"
describe the earlier design.

## 0. Update 23 Nov 2026 — UI completion pass, committed

Reels is now committed on `feat/calls-720p-and-app-icon` (flags still
default **off**: `REELS_ENABLED`, `DASHURI_REELS_ENABLED`). The restore kit
in `docs/reels/experiment` is obsolete (roll back with `git revert`); only
its two `drop_*.sql` rollback scripts are kept in git.

UI fixes in this pass:
- **Landscape / large text:** the creator name, Follow and caption were
  laid out ~350 px above the top of the screen (invisible), and the action
  column slid under the transparent app bar, which swallowed taps on Like.
  The info panel is now bounded below the app bar and scrolls only when it
  overflows; the action columns scale down instead.
- Long captions: 3 lines, then **more / less** (expanded text scrolls).
- Blocking a creator from a reel removes all their reels from the feed once
  the safety flow confirms the block (it pops `true`).
- Readability over any frame: text shadows on all overlay text and action
  labels, translucent backing for the For you / Following tabs and the
  "Following" button; like icon animates when its state changes.
- Dark Mode: status colours from the theme tones; light and dark audited.
- Tests: `test/presentation/reels_polish_test.dart` (captions across the
  full responsive matrix, block confirmed/cancelled, contrast audit of
  feed/empty/error in both themes). 235 Reels tests pass.

**Update 27 Nov 2026 (second closed-testing prep):** playback is built.
`VideoPlayerReelFactory` (`video_player`, approved by the founder) plays the
R2 MP4 URLs; see §5. Mux is no longer needed (R2 + own processing,
`DASHURI_REELS_R2_MIGRATION.md`). **Still blocked:** Cloudflare R2
credentials and Sightengine keys; nothing has played against real R2 yet.

## 1. Summary

| Stage | Status |
|---|---|
| 1. Audit, architecture, PRD, provider research, financial model | Done |
| 2. Database, Go API, media provider abstraction | Done (Mux adapter written against the documented API; **no credentials, never called live**) |
| 3. Flutter Reels and creator experience | Done, including playback (`video_player`, 27 Nov). Not yet played against real R2 |
| 4. Moderation, analytics, integration | Done (Sightengine frame adapter; **no live calls made**) |
| 5. Tests, local demo, docs | Done. All suites pass (§3) |

Nothing was committed, pushed, deployed or migrated on a hosted database. No paid service was activated.

**Related experiment (22 Nov 2026):** unified chat + in-call messaging, and a
P0 responsiveness audit that fixed overflows in Reels too. See
`docs/chat/UNIFIED_CHAT_AND_IN_CALL_MESSAGING.md` and
`docs/chat/RESPONSIVENESS_AUDIT.md`.

## 2. Built, designed only, and needing credentials

**Built and tested locally:**
- the `reels` schema, with a database-level publication guard and RLS;
- 17 endpoints and 4 jobs;
- feed ranking and pagination;
- the upload lifecycle;
- moderation (automated, human, reports, appeals);
- the Mux adapter (direct upload, assets, signed HLS and thumbnails, webhook verification, deletion);
- the Sightengine frame classifier;
- analytics and call attribution;
- account and video deletion;
- the Flutter Reels tab, creator profile, upload flow and my-reels statuses;
- feature flags on both sides;
- the financial simulator;
- the restore mechanism (verified).

**Designed or documented only:**
- 5-tab navigation (Home / Discover-Reels / Connect / Inbox / Profile). A Reels tab was added instead.
- Web landing page for shared links (`https://dashuri.app/r/<id>`). **The link does not resolve yet.**
- Moderator UI. Endpoints exist; there is no admin app, as elsewhere in Dashuri.
- Caption contact-detail filtering.
- Audio fingerprinting.
- Push notifications for moderation results.

**Needs credentials before anything works end to end:**
- **Mux:** `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, signing key id and base64 private key, webhook secret. Plus a webhook URL pointing at `/v1/webhooks/reels/mux`.
- **Sightengine:** the existing call-moderation keys. Without them every reel goes to human review.
- The usual Supabase and API config for the app.

## 3. Test results (actually run on 22 Nov 2026)

| Suite | Command | Result |
|---|---|---|
| Full repo validation (format, analyze, dependency rules, all Dart/Flutter tests, Go format, vet, race tests, build, migrations + 11 invariants) | `scripts/validate.sh` | **All checks passed** (exit 0) |
| Dart/Flutter tests, 20 packages | `melos run test` (inside validate) | **879 passed, 0 failed** (was 815: +62 `feature_reels`, +2 app flag tests) |
| `feature_reels` | `flutter test` | 62 passed: domain (MP4 duration, validation), data (wire format against a real local HTTP server), 15 Cubit tests, widget tests at 390×844, 1024×768 and 360×640 with 1.3× text |
| App routing with the flag on and off | `apps/mobile/test/router/reels_flag_test.dart` | Passed: flag off means no Reels route or tab; flag on keeps every existing route |
| Go unit tests (race) | `go test -race ./...` | All packages pass; 125 tests and subtests |
| Go integration on a throwaway Postgres as `api_service` | `scripts/test-backend-integration.sh` | **All packages pass**, including 10 Reels integration tests |
| Reels financial model | `node docs/reels/sim/validate.mjs` | 32 / 32 |
| Simulator in headless Chrome (1280 px and 500 px) | harness in the session scratchpad | 24 / 24 at each width |
| Reels schema rollback | `drop_reels_schema.sql` on a throwaway database | Drops only `reels.*`; 11 / 11 invariants still pass |
| Restore | `restore.sh --apply` on a full copy of the working tree | **Verified:** every tracked file and every `docs/finance` file matches the baseline SHA-256; no extra or missing files; a deliberately tampered file is detected |

**Reels integration tests:**
- first reel → human review → published, then the next reel published automatically;
- the database refuses publication without a decision; decisions are append-only;
- fail closed with no classifier and during an outage;
- reject → appeal → restore; 75 s video → failed;
- feed pagination with 25 reels and no duplicates; blocks, reports and the Following feed;
- likes and views are idempotent; consent-gated events; share; a `minor_safety` report hides the reel;
- deletion, media purge and account cleanup;
- 14 concurrent uploads → exactly 10 accepted;
- attribution: a new viewer is counted, an existing customer is not;
- `anon` and `authenticated` cannot read `reels`.

**Bugs the tests caught and fixed during the work:**
- a SQL parameter type-inference error in `MarkReady`;
- `StatusTag` overflowing in narrow grid tiles;
- the creator count row overflowing at 360 px with 1.3× text;
- DELETE responses carrying no body, so like and follow became an idempotent `PUT {bool}`.

**Not tested:**
- real Mux uploads and playback;
- real Sightengine calls;
- device camera and gallery (the `image_picker` adapter is thin and untested on a device);
- Flutter `integration_test` on an emulator.

## 4. Known defects and risks

1. ~~No playback in this build.~~ Fixed 27 Nov (§5). Remaining: a presigned URL lives 6 h, so a feed left open longer fails to play; "Try again" re-opens the same URL and fails again until the feed is refreshed.
2. **Shared links point to a page that does not exist** (`dashuri.app/r/<id>`).
3. **Large files are read fully into memory** before upload (a limit of 150 MB applies). Streaming or resumable upload (tus) is better for long clips on low-end phones.
4. **The device duration check reads MP4/MOV `mvhd` only.** Other containers are refused with a clear message; the server re-checks the duration anyway.
5. **Moderation samples still frames.** Audio, and very brief content between frames (2 s), are not analysed automatically. Reports and human review cover the gap.
6. **Captions are not yet filtered** for contact details.
7. **Ranking reads up to 400 candidates per page request.** That is fine for the MVP; it needs a materialised candidate table at scale.
8. **The first-reel human review is an operational commitment** that someone must staff.
9. **Mux is US-processed.** Disclose this in the privacy policy (DPDP) and confirm Mux's acceptable-use policy for an 18+ product.
10. **Financial impact is entirely assumed.** On base assumptions Reels lowers six-month profit by about ₹32k (see the financial analysis).

## 5. Video playback (built 27 Nov 2026)

`packages/features/reels/lib/src/presentation/widgets/video_reel_player.dart`, registered by `registerReelsFeature` as the `ReelPlayerFactory`.

- **At most two players:** the active reel and the next one (preloaded paused and muted, so a swipe starts instantly). Every other reel holds none; swiping away disposes the player.
- **Stops** when the user pauses, when swiping away (rewinds and reports watch time), when the app goes to the background, and when the feed is not on screen. Another tab, or a route pushed on top such as an incoming call or a creator profile, both turn `TickerMode` off.
- **States:** poster until the first frame; a spinner while loading or buffering; on a network error, "Couldn't play this reel" with **Try again**.
- **Analytics:** `onStarted` once per activation, `onCompleted` once even though the reel loops, `onStopped` with the watched time when it is left early.
- **Reduce motion** (system setting): reels start paused; a tap plays them.
- **Tests:** `test/presentation/video_reel_player_test.dart` (9, with a fake controller), plus the cubit's reduced-motion test. The Android debug APK builds with the plugin.
- **Not verified:** playback on a device against real R2 URLs (no bucket yet).

## 6. Every changed file

**Modified (12 files; originals in `docs/reels/experiment/backup/`; about 100 lines added in total):**

| File | Change |
|---|---|
| `backend/internal/platform/config/config.go` | `REELS_ENABLED`, `MUX_*` and `REELS_MODERATION_*` settings; `getInt` |
| `backend/internal/app/wire_mvp.go` | One line mounting the Reels routes |
| `api/openapi/dashuri.v1.yaml` | Reels tag, 17 paths, 25 schemas (appended) |
| `pubspec.yaml` | Workspace member `packages/features/reels` |
| `apps/mobile/pubspec.yaml` | Path dependency `feature_reels` (no external packages) |
| `apps/mobile/lib/app/app.dart` | Passes `reelsEnabled` to the router |
| `apps/mobile/lib/app/di/injector.dart` | Registers Reels and the video picker **only when the flag is on** |
| `apps/mobile/lib/app/router/app_router.dart` | `reelsEnabled` parameter (default false) |
| `apps/mobile/lib/app/router/role_shells.dart` | `reelsTab`, `customerTabsFor`, `composeRoutes(reelsTab:)` (default false) |
| `packages/core/lib/src/config/app_config.dart` | `reelsEnabled` from `DASHURI_REELS_ENABLED` |
| `packages/navigation/lib/src/route_paths.dart` | 4 Reels paths |
| `packages/network/lib/src/http/api_client.dart` | Optional `onProgress` on `uploadToSignedUrl` |

`pubspec.lock` was backed up and is **unchanged**. `go.mod` and `go.sum` are **unchanged**. No existing migration was edited.

**Created:**
- `supabase/migrations/20261123000100_reels_experiment.sql`
- `backend/internal/modules/reels/`:
  - `module.go`, `ports.go`, `dto.go`, `service.go`, `moderation.go`, `http.go`
  - `reels_test.go`, `reels_integration_test.go`
- `backend/internal/modules/reelsrank/`: `reelsrank.go`, `reelsrank_test.go`
- `backend/internal/adapters/mux/`: `mux.go`, `mux_test.go`
- `backend/internal/adapters/postgres/reels_repo.go`
- `backend/internal/adapters/sightengine/reels_frames.go`, `reels_frames_test.go`
- `backend/internal/app/wire_reels.go`
- `backend/internal/jobs/reels.go`
- `packages/features/reels/`: the whole package (lib: 18 files; test: 7 files)
- `apps/mobile/lib/app/platform/device_video_picker.dart`
- `apps/mobile/test/router/reels_flag_test.dart`
- `docs/reels/`:
  - the 7 documents and the simulator;
  - `sim/`: model, validation, template, build;
  - `experiment/`: baseline, manifests, backups, restore, rollback SQL, OpenAPI script

**Ignored build output** (regenerated, not tracked): `packages/features/reels/.dart_tool`, `packages/features/reels/build`, and `packages/features/reels/.flutter-plugins-dependencies` are deleted with the package. Shared caches (`.dart_tool/package_config.json`) refresh with `flutter pub get`.

## 7. Running it locally

```bash
# Backend (Reels on; Mux/Sightengine optional — without them uploads say "not configured"
# and reels go to human review)
cd backend && DASHURI_ENV=development REELS_ENABLED=true DATABASE_URL=… go run ./cmd/api
#   jobs: go run ./cmd/worker reels-moderate | reels-reconcile-uploads | reels-purge-media | reels-account-cleanup

# App (adds the Reels tab)
cd apps/mobile && flutter run --dart-define-from-file=config/development.json --dart-define=DASHURI_REELS_ENABLED=true

# Tests
./scripts/validate.sh
DASHURI_TEST_PG_PORT=55646 ./scripts/test-backend-integration.sh ./internal/modules/reels/...
node docs/reels/sim/validate.mjs && node docs/reels/sim/build.mjs

# Financial simulator
open docs/reels/DASHURI_REELS_FINANCIAL_SIMULATOR.html
```

Apply the migration only to a **local** Supabase stack (`supabase db reset` or `supabase migration up`), never to production.

## 8. Disabling Reels

**Server:** leave `REELS_ENABLED` unset or `false`, the default. Every Reels endpoint then returns `503 reels_disabled` and the jobs skip.

**App:** omit `DASHURI_REELS_ENABLED`, the default. No Reels tab, route or DI registration exists.

Both are tested.

## 9. Removing the experiment (restore the previous state)

```bash
docs/reels/experiment/restore.sh                         # dry run: lists what changes
docs/reels/experiment/restore.sh --apply                 # restore, then verify every tracked file by SHA-256
docs/reels/experiment/restore.sh --apply --purge-docs    # … and delete docs/reels
flutter pub get                                          # refresh workspace resolution
# Only if you applied the migration to a local/staging DB yourself:
psql … -f docs/reels/experiment/drop_reels_schema.sql    # run before --purge-docs
```

The script uses no git commands. It was verified on a full copy of the working tree. Because HEAD is unchanged and nothing was committed, `git diff` also shows exactly what the experiment changed.
