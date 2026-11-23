# Dashuri Reels — architecture (EXPERIMENT)

## 1. Audit of the existing implementation (before any change)

Starting point: branch `feat/calls-720p-and-app-icon`, HEAD `d8c55fa`. The tracked tree was clean; `docs/finance/` was untracked (see `experiment/BASELINE.md`).

| # | Area | What exists (read from the code) | Consequence for Reels |
|---|---|---|---|
| 1 | Navigation | `go_router`, composed from each feature's `FeatureRoutes` / `TabFeatureRoutes`. Two role shells: customer (Discover, Chats, Wallet, Profile) and host (Home, Calls, Earnings, Profile), with a bottom bar on phones and a rail on tablets (`AdaptiveShell`) | Reels adds one optional customer tab through the same composition. No existing route changes |
| 2 | Creator / host identity | `identity.accounts.roles`, `identity.profiles`; hosts in `hosting.hosts` (`state`, `kyc_state`, `rate_per_minute`, `is_available`, heartbeat). One account can be both customer and host (D-04) | Creator = any 18+ account. Host features are read from `hosting.hosts`; nothing is copied |
| 3 | Profiles | `identity.profiles` plus `identity.profile_photos` (private bucket, signed URLs, moderator approval) | Creator profiles reuse name, photo and languages; a `reels.creator_profiles` row only adds a bio |
| 4 | Video and media | Stream Video for **live calls only**. No video-on-demand, no `video_player`, no camera package. `image_picker` is in the app (supports `pickVideo`) | Video-on-demand needs a new provider and a playback package (pending approval) |
| 5 | Storage and upload | Supabase Storage signed upload tickets (photos); `ApiClient.uploadToSignedUrl` (PUT) | The same PUT-to-signed-URL flow fits Mux direct uploads. Upload progress was added (optional parameter) |
| 6 | Moderation | Sightengine nudity frames during the first 180 s of calls; `safety.reports`, `enforcement_actions`, `appeals`; `moderation.decisions` (append-only); photo review queue | The call pipeline is live-frame based, so a **separate pre-publication pipeline** is needed. It reuses the Sightengine account and blocks |
| 7 | Notifications | FCM from the server, `notify.inbox`, Supabase Realtime. The app has no `firebase_messaging` | Reels sends no notifications in the MVP (the creator sees status in-app) |
| 8 | Database | Supabase Postgres; one schema per domain; RLS **forced** on every table; only `api_service` / `worker_service` may access; `anon` / `authenticated` revoked | Same pattern for the new `reels` schema |
| 9 | Ledger | Double-entry ledger (Diamonds, Beans), templates only, balance locks | **Untouched.** Reels moves no money. Calls started from a reel use the existing flow |
| 10 | Testing / CI | `scripts/validate.sh` (format, analyze, dependency rules, `melos test`, Go vet and race, migrations); integration tests on a throwaway Postgres as `api_service`; no hosted CI | All of it is used for Reels (see the implementation status) |

## 2. Shape

```text
 Flutter app                                  Go API (modular monolith)                    Providers
 ──────────                                   ────────────────────────                    ─────────
 feature_reels ──ApiClient──▶ /v1/reels/*  ─▶ modules/reels (service, http)  ──VideoProvider──▶ Mux (direct upload,
   domain   (entities, ports, use cases)       modules/reelsrank (pure ranking)                    signed HLS, thumbnails,
   data     (remote data source)               adapters/postgres/reels_repo ─▶ reels schema        webhooks)
   application (3 Cubits)                      adapters/mux                                     Sightengine (frames)
   presentation (3 pages)                      adapters/sightengine/reels_frames ─FrameClassifier─▶
       │ PUT file ───────────────────────────────────────────────────────────────────────────▶ Mux upload URL
       │ HLS (signed) ◀──────────────────────────────────────────────────────────────────────── stream.mux.com
       └─ "Video call" → existing /hosts/:id/call (pre-call, billing, Beans: unchanged)
 Worker jobs: reels-moderate (1 min), reels-reconcile-uploads (5 min), reels-purge-media (hourly), reels-account-cleanup (daily)
```

### Why one Go module instead of seven

The brief suggested `reels`, `reels_feed`, `reels_engagement`, `creator`, `media`, `reels_moderation` and `reels_analytics`. They share one aggregate (the video) and its transaction boundaries. Publication, reports, deletion and likes all lock the same row. Splitting them would force a port for every query and a cross-module transaction protocol.

So there is **one module** with one file per concern:

| File | Concern |
|---|---|
| `service.go` | creators, uploads, feed, engagement, analytics events |
| `moderation.go` | moderation pipeline, webhooks, reports, appeals, admin, jobs |
| `http.go` | thin handlers |
| `ports.go` | the `VideoProvider`, `FrameClassifier` and `Repository` contracts |

On top of that:
- **`reelsrank`** is a pure library (like `keyset` and `economy`), so the ranking can be replaced without touching the module.
- **Media** is behind `VideoProvider`.

Dependency rules hold:
- the module imports only `platform/*`, `keyset` and `reelsrank`;
- vendors live only in `adapters/`;
- `app` is the composition root.

### Flutter

`packages/features/reels` follows the existing layers:
- **domain** is pure Dart, including the MP4 duration reader;
- **data** implements the domain contract with `ApiClient`;
- **application** has three Cubits with sealed states;
- **presentation** has three pages and the reel view;
- **DI and routes** live in `di/` and `routes/`.

It imports no other feature. Cross-feature navigation uses `RoutePaths`:
- pre-call: `preCall`;
- host profile: `hostProfile`;
- report/block: `report?mode=block`.

`tool/check_dependencies.dart` passes.

Two device capabilities are **ports**:
- **`ReelVideoPicker`**: implemented in the app with the existing `image_picker`.
- **`ReelPlayerFactory`**: not implemented until `video_player` is approved. Without it, the reel view shows the poster and an honest "playback unavailable" label, and no play or mute controls.

## 3. Feature flags and failure isolation

| Switch | Off (default) | On |
|---|---|---|
| `REELS_ENABLED` (server) | Every Reels endpoint returns `503 reels_disabled`; jobs are no-ops; nothing else changes | Endpoints and jobs run |
| `DASHURI_REELS_ENABLED` (app, `--dart-define`) | No Reels route, tab or DI registration exists (tested) | Reels tab after Discover |
| Mux credentials missing | `GET /v1/reels/config` says `uploads_available: false`; upload returns `503 video_provider_not_configured`; the app shows "uploads aren't set up" | — |
| Sightengine missing or failing | Reels go to **human review** (fail closed), never to the public | — |

**Provider outage.** A Mux or Sightengine outage affects only Reels endpoints:
- webhooks are retried;
- `reels-reconcile-uploads` polls stuck uploads;
- moderation retries for 30 minutes and then queues human review.

Calls, wallet, chat and discovery do not call Reels code. The only shared code paths are the additive `onProgress` parameter on `ApiClient.uploadToSignedUrl`, and the `customerTabsFor`/`composeRoutes(reelsTab:)` parameters. Both default to the previous behaviour.

## 4. Video lifecycle

```text
POST /v1/reels/uploads ─▶ awaiting_upload ──(Mux: upload.asset_created | reconcile poll)──▶ processing
processing ──(Mux: asset.ready, duration 14.1–60.9 s)──▶ pending_moderation        (outside the range ─▶ failed)
pending_moderation ──(reels-moderate)──▶ published        (clean, and creator already has a human-approved reel)
                                    └──▶ in_review        (first reel / uncertain / classifier unavailable)
                                    └──▶ rejected         (clear violation; appealable; media held 90 days)
in_review ──(moderator)──▶ published | rejected
published ──(minor_safety/nudity report, or 3 reporters)──▶ in_review ──▶ published | removed
rejected | removed ──(appeal + moderator restore)──▶ published
any ──(creator delete / account deletion)──▶ deleted ──(reels-purge-media, after any hold)──▶ media purged
```

The database refuses `→ published` unless the latest moderation decision is `approve` or `restore` (trigger `reels.guard_publication`). This is tested: no code path can publish unmoderated content.

## 5. Playback security

- Mux assets are created with `playback_policies: ["signed"]`. A playback id alone does not play.
- The API signs HLS and thumbnail URLs as RS256 JWTs (`kid` = Mux signing key; `aud` = `v` or `t`; `exp` = 6 hours) **only** for:
  - published reels the viewer may see (not blocked);
  - the creator's own reels;
  - the moderator review queue (15-minute tokens).
- Clients never receive Mux credentials. The upload URL is single-use and expires in 2 hours.

## 6. Feed ranking (`reelsrank`, deterministic, explainable)

**Candidates:** published reels from the last 30 days, at most 400, excluding:
- the viewer's own reels;
- reels by creators blocked either way;
- reels the viewer reported.

The candidate set is pinned by `as_of`, which is carried in the cursor.

**Score** = sum of the terms below, each visible through `Explain()`:

| Term | Default |
|---|---|
| Following the creator | +1.0 |
| Freshness | 1.2 × 0.5^(age h ÷ 36) |
| Viewer language matches | +0.6 |
| Engagement (smoothed like rate) | 1.0 × (likes + 1) ÷ (views + 20) × 5 |
| Completion (smoothed) | 0.8 × (completions + 1) ÷ (views + 4) |
| Creator affinity (viewer liked their reels) | up to +0.3 |
| Host online now (contextual) | +0.15 |
| Already seen | −1.5 |
| Reports | −0.5 per reporter, capped at 4 |

**Paging:**
- Order is score descending, then id descending (a total order).
- Cursor = (`as_of`, last score, last id). The next page is every item strictly after that position, so pages never overlap within a session (tested with 47 items, and end to end with 25 reels).
- Within a page, `Diversify` avoids the same creator twice in a row. The cursor is taken before diversifying.
- The client also drops any id it already has.

**Following tab:** keyset paging on (`published_at`, `id`) over followed creators.

**Upgrade path:** replace `reelsrank.Score` (or `Rank`) with a learned model behind the same `Candidate` / `Ranked` types; the API and the app are unaffected.

## 7. Analytics and attribution

| Event | Who records it | Stored only with analytics consent |
|---|---|---|
| `reel_impression`, `reel_play_started`, `reel_play_completed`, `reel_watch_duration`, `creator_profile_opened`, `host_call_cta_clicked` | App (`POST /v1/reels/events`, batches of ≤ 50 with a random session id) | yes |
| `reel_liked`, `creator_followed`, `reel_shared`, `reel_reported` | Server, inside those endpoints (never trusted from the client) | yes |
| Views and completions (counters) | Server, from play events. One row per viewer, reel and day, so counts are idempotent | Functional data, kept without consent; ids only |
| `reel_attributed_call_started`, `reel_attributed_call_completed` | **Derived on read** in `GET /v1/admin/reels/analytics`, never logged by a client | — |

Events contain no captions, free text, device data or locations.

**Attribution rule.** A paid call counts as reel-attributed only if all of these hold:
1. the caller clicked **that host's** reel call button within **30 minutes before** the call was created;
2. it is not a free call;
3. the caller had **no ended paid call with that host in the 30 days before the click**, so existing relationships are not credited to Reels;
4. each call is counted once.

Watching a reel at some point is never enough. The integration test covers a new viewer (counted) and a regular customer (not counted).

## 8. Jobs

| Job | Schedule | Purpose |
|---|---|---|
| `reels-moderate` | every minute | Automated frame check, at most 25 per run |
| `reels-reconcile-uploads` | every 5 minutes | Finds lost webhooks: polls stuck uploads and processing assets; expires abandoned uploads after 3 hours |
| `reels-purge-media` | hourly | Deletes provider media of deleted, rejected, removed or failed reels after any evidence hold, and never while an appeal is open |
| `reels-account-cleanup` | daily | After `execute-account-deletions`: deletes the account's reels, likes and follows, clears the bio, and writes an audit event |

All jobs are idempotent and bounded, and skip when `REELS_ENABLED=false`.
