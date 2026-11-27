# Reels video: replacing Mux with Cloudflare R2 + our own processing

Status 27 Nov 2026. **Built and tested locally only.** No Cloudflare
account, no credentials, nothing deployed, no migration applied on the
hosted database, no media moved. Reels flags stay off.

Founder direction (27 Nov 2026): remove recurring Mux cost. R2 + our own
processing on the existing Go backend and Cloud Run is the **target**, not
an optional extra. Mux stays wired only so the move is safe, and is removed
once nothing depends on it (§5).

## 1. What Mux did and what replaces it

| Mux capability | Replacement (built) | Where |
|---|---|---|
| Direct upload URL | Presigned R2 `PUT` with **Content-Length and Content-Type signed in**, so R2 refuses any other file (e.g. a 5 GB upload). Valid 1 h. | `adapters/r2/provider.go` `CreateUpload`, `sigv4.go` |
| Upload webhook | App calls `POST /v1/reels/{id}/upload-complete`. The server HEADs the object itself and never trusts the call. `reels-reconcile-uploads` is the fallback when the app never calls. | `modules/reels/service.go` `CompleteUpload` |
| Validation | Size (HEAD, then a bounded download). ffprobe checks: container in an allow-list, a video stream, 240–4096 px on the short/long side, 14.1–60.9 s. Rejections get a reason code: `file_too_large`, `invalid_media`, `unsupported_format`, `no_video_stream`, `resolution_too_low`, `duration_out_of_range`, `upload_missing`. | `adapters/r2` `Process`, `adapters/ffmpeg` |
| Transcoding | ffmpeg to H.264 High, 720p short side (never upscaled), CRF 26 capped at 2.5 Mb/s, AAC 96 kb/s, `+faststart`. Files already within that policy are only remuxed (no re-encode, near-zero CPU). | `adapters/ffmpeg` `Transcode` |
| Thumbnail | Poster JPEG at 1 s, ≤ 720 px. | `Still` |
| Moderation frames | One JPEG still every `REELS_MODERATION_FRAME_SECONDS` (2 s), ≤ 31 stills, ≤ 512 px, stored under `frames/`. Moderation gets presigned URLs, exactly as it got Mux frame URLs. | `FrameTimes`, `FrameURLs` |
| Signed HLS playback | Presigned `GET` of `playback.mp4` (6 h; 15 min for moderators). Progressive MP4, played by Flutter `video_player`. | `Playback` |
| Asset deletion | Deletes every object under `reels/<id>/`. | `DeleteAsset` |

**Moderation is unchanged and still fails closed.** A processed reel goes to
`pending_moderation` exactly as a Mux reel did, and the same `reels-moderate`
job and thresholds apply. With no classifier, no stills, or a classifier
outage, the reel goes to human review. It is never published without a
decision, and the database guard on publication is untouched.

### Object keys (bucket stays private)

```
reels/<reel_id>/original        upload; deleted after processing (R2_KEEP_ORIGINALS=false)
reels/<reel_id>/playback.mp4    what users watch
reels/<reel_id>/thumbnail.jpg   poster
reels/<reel_id>/frames/0002000.jpg  moderation stills (time in ms)
reels/<reel_id>/manifest.json   processing result, written LAST (commit point, makes Process idempotent)
```

Postgres stores the keys, not URLs. Migration
`20261127000100_reels_r2_media.sql` adds the following columns to
`reels.videos`:

- `width`
- `height`
- `size_bytes`
- `video_storage_key`
- `thumbnail_storage_key`

The migration is additive only. The existing `provider` column says where
each reel lives (`r2` or `mux`).

### Processing runs in a separate media worker

The API image is distroless and has no ffmpeg; it only presigns URLs.
`backend/Dockerfile.media` is the same worker binary plus pinned static
ffmpeg, and runs only the `reels-process-media` job. If that job ever runs
somewhere without ffmpeg, reels **wait**; they are never failed for it.
Transient errors (timeouts, storage hiccups) are retried for 2 h, then the
reel fails as `processing_failed`. Failed reels' media is purged by
`reels-purge-media`, so nothing is orphaned.

### Claims, retries and expiry (added 27 Nov 2026, migration `20261127000400`)

- **One worker per reel.** `reels-process-media` claims due reels with
  `FOR UPDATE SKIP LOCKED` and a 20-minute lease
  (`processing_lease_until`), so overlapping executions never transcode the
  same reel twice. Tested with 8 concurrent runs over 4 reels: 4 `Process`
  calls.
- **Backoff, not a retry on every run.** A transient failure releases the
  claim with a wait of 2, 4, 8, 16, then 32 minutes
  (`processing_next_attempt_at`), so one flaky reel never blocks newer
  uploads. The reel fails as `processing_failed` after 6 attempts or 2 h from
  the first claim (`processing_started_at`), whichever comes first.
- **No ffmpeg on this instance:** claims are handed back without counting an
  attempt.
- **Uploads that never arrive** fail as `upload_expired` after 3 h. If the
  storage cannot be asked (an outage, or the provider is no longer
  configured), they fail after 24 h instead of waiting forever.
- **The app** explains each processing code in plain language. Processing
  failures are never shown as rule violations.

### Untrusted-input hardening (ffmpeg)

- `-protocol_whitelist file`: no network fetches (SSRF).
- `-format_whitelist mov,mp4,…,matroska,webm`: playlist and concat demuxers
  can never run. Tested: an HLS playlist pointing at `/etc/hosts` is refused.
- Every run has a timeout and output caps on length and size.
- `-map_metadata -1` strips GPS location, device and creation time from
  every output. Tested: a location tag does not survive.

## 2. Transition: both providers at once

- `REELS_VIDEO_PROVIDER=r2` (the default) sends new uploads to R2.
- Mux remains a *legacy* provider. Reels stored with Mux keep playing,
  moderating and purging while `MUX_*` credentials are set.
- Each reel row is served by its own provider (`reels.videos.provider`).
- `REELS_VIDEO_PROVIDER=mux` flips new uploads back to Mux as an emergency
  rollback, with no code change.

API: `playback.url` + `playback.format` (`mp4` | `hls`) are canonical.
`hls_url` is kept for older app builds (it equals `url` for HLS and is empty
for MP4). The upload ticket adds `upload_headers`; the create-upload request
adds `size_bytes` and `content_type`, both required for R2.

Fact that makes this easy: **no reel has ever been stored with Mux.** Mux
credentials were never configured, and the hosted database has no reels
schema. There is no media to migrate today.

## 3. Verified locally (27 Nov 2026)

| Check | Result |
|---|---|
| SigV4 signer against the AWS S3 documentation examples (presigned GET and header-signed GET) | pass |
| R2 provider against an in-memory S3 fake that **re-verifies every signature** (presigned URLs re-signed from the request received) | 12 tests pass |
| Real ffmpeg: 1080×1920 16 s clip processed to 720×1280 MP4 + poster + 8 stills + manifest | pass |
| Re-running processing returns the stored result (idempotent) | pass |
| Delete removes all objects | pass |
| Upload of a larger file or a different type than declared is refused | pass |
| A presigned URL re-pointed at another key is refused | pass |
| Bad media fails with the right code: not-a-video, HLS playlist, too short, too large (original deleted) | pass |
| Service + real Postgres (all migrations): upload, upload-complete (only the creator; 409 before the file arrives; idempotent), processing writes width/height/size/keys, moderation first-reel review, processor unavailable means waiting, transient errors retry then give up, failed media purged, legacy Mux reel still served as HLS | 20 integration tests pass (17 existing + 3 new) |
| `go vet`, `gofmt`, `go test -race ./...`, `go build`, migration invariants | pass |
| Flutter Reels package (236 tests), network package, `dart analyze --fatal-infos` | pass |

**Not verified:**

- Against real Cloudflare R2 (no account). In particular, that R2 enforces a
  signed `Content-Length` on presigned PUT the way the fake does. This must
  be checked first once a bucket exists; if it doesn't, the HEAD size check
  in `Process` still deletes oversized files, but storage would be used
  until then.
- ~~`Dockerfile.media` build~~ **Built locally 27 Nov** (`dashuri-media-worker:local`, 330 MB): ffmpeg 7.1 with libx264 and AAC; a 1080×1920 → 720p H.264 encode works as the non-root user in `/tmp`; the worker refuses to start without production config (`SUPABASE_URL`, `SIGHTENGINE_API_SECRET`). Not pushed to any registry.
- Cloud Run CPU time (only measured on an Apple M4, §4).
- App playback: `video_player` isn't integrated yet (next phase).

## 4. Cost (estimates; re-check prices before go-live)

**Cloudflare R2.** Free each month: 10 GB-month storage, 1 M Class A
operations (writes and lists), 10 M Class B operations (reads and HEADs),
egress always free. Beyond that, the list prices I'm using are $0.015 per
GB-month, $4.50 per million Class A and $0.36 per million Class B. Confirm
them on Cloudflare's pricing page. Cloudflare may require a payment method
even for free-tier use; that is still open.

**Per reel:**

- Storage is about 8–20 MB: 7.3 MB measured for a 60 s synthetic clip,
  about 19.5 MB at the bitrate cap, plus about 1.3 MB of poster and stills.
  The original is deleted.
- About 36 Class A operations per upload. Deletes are free.
- Per view, the poster plus a few range GETs: about 2–5 Class B operations.

**What the free tier covers:**

- Roughly 500–1,000 stored reels (10 GB).
- About 27,000 uploads a month (1 M Class A).
- About 2–5 M views a month (10 M Class B).

The cost driver is storage growth, not views.

**Cloud Run processing.** On an Apple M4, a 60 s 1080p clip took about 16
CPU-seconds to transcode. A Cloud Run vCPU is slower, so assume 30–60
vCPU-seconds per reel. Files already within policy are only remuxed and
cost about 1 s. Beyond the Cloud Run free allowance, that is roughly
$0.001 per reel at about $0.000018 per vCPU-second.

**Hidden cost: idle polling.** Every scheduled job execution is a container
start, even when there is nothing to do. The job is therefore documented as
every **5 minutes**, not every minute. Better still: start the job execution
from `upload-complete` (Cloud Run Jobs "run" API), so it runs only when there
is work. Not built yet; it needs the deploy setup. Cloud Scheduler gives 3
free jobs per account, and each further job is billed monthly.

**Delivery choice.** The bucket is private and the app gets presigned
URLs. This is safe (takedowns are immediate, nothing is public) and free of
egress fees. The trade-off is no Cloudflare edge cache, so every view counts
Class B operations.

A public custom domain would cache at the edge and cut Class B operations,
but removed reels would stay reachable by URL until purged. If that's ever
needed, use a second public bucket holding only published playback files,
deleted on takedown. Not built.

## 5. Remaining Mux dependencies (all must go before Mux is removed)

| # | Dependency | What replaces it / action |
|---|---|---|
| 1 | `backend/internal/adapters/mux/` (adapter + tests) | Delete. |
| 2 | `backend/internal/app/wire_reels.go`: `mux.New`, legacy wiring, `REELS_VIDEO_PROVIDER=mux` option | Wire R2 only; drop `Legacy`. |
| 3 | `config.go`: `MuxTokenID/Secret/SigningKeyID/SigningKeyBase64/WebhookSecret`; `.env.example` `MUX_*` | Delete. |
| 4 | `POST /v1/webhooks/reels/{provider}` and `HandleWebhook`, `reels.videos.provider_asset_id`/`playback_id` Mux semantics, `reels.webhook_deliveries` | Keep the route until (1); then remove or keep as a 404. Columns stay (R2 uses the reel id). |
| 5 | Any reels rows with `provider = 'mux'` | None exist today. If some appear: re-upload each through processing, or keep Mux until they're deleted. |
| 6 | API `hls_url` field and the app's HLS branch (`ReelMediaFormat.hls`) | Remove `hls_url` once no app build reads it. Keep `format` for future variants. |
| 7 | `reels.ReconcileUploads` asset polling and `VideoProvider.Asset/ParseWebhook` (only Mux needs them) | Simplify the interface after (1). |
| 8 | Docs that assume Mux: `DASHURI_VIDEO_PROVIDER_COMPARISON.md`, `DASHURI_REELS_ARCHITECTURE.md`, `DASHURI_REELS_IMPLEMENTATION_STATUS.md`, `DASHURI_REELS_DATABASE_AND_API.md`, and the Reels financial simulator (`DASHURI_REELS_FINANCIAL_SIMULATOR.html`, `sim/*`) which prices video with Mux rates | Re-base on R2 + Cloud Run numbers (§4). |
| 9 | `adapters/sightengine` reels frame test fixtures use Mux-style URLs | Cosmetic. |

Not dependencies, despite the name: `http.ServeMux` (`mux` variables in
handlers) and ffmpeg "remux".

## 6. Go-live requirements (each step needs founder approval)

**Current state (27 Nov 2026):** complete and tested locally; **switched off**.
`REELS_ENABLED=false` (server) and `DASHURI_REELS_ENABLED` unset (app). No
Cloudflare account, credentials, bucket, registry image, Cloud Run job or
hosted migration exists. With R2 unconfigured, the server reports uploads
unavailable (`GET /v1/reels/config`), and the app shows "Video uploads aren't
set up on this server yet" instead of failing after recording.

### 6.1 R2 credentials

- A Cloudflare account. Check whether a payment method is required even for
  the free tier, and ask before adding one.
- One **R2 API token** scoped to the single bucket, permission *Object Read &
  Write*. No account-wide token.
- Stored only as Cloud Run secrets (Secret Manager), never in the repo or the
  app:
  - `R2_ACCOUNT_ID`
  - `R2_ACCESS_KEY_ID`
  - `R2_SECRET_ACCESS_KEY`
  - `R2_BUCKET`
- Both the API service (presigning) and the media job (processing) need them.
  `R2_ENDPOINT` stays empty (it exists only for local S3-compatible fakes).

### 6.2 Bucket configuration

- **Private** bucket. No public access, no `r2.dev` URL, no custom domain (§4,
  "Delivery choice").
- Location hint: Asia-Pacific (users are in India).
- **CORS: none needed.** The Android app uploads with plain HTTPS PUT, not
  from a browser. Add CORS only if a web client ever uploads.
- **Lifecycle rule:** delete objects under `reels/*/original` older than 2
  days. This is a safety net; processing deletes originals, and
  `reels-purge-media` deletes everything else.
- Object keys are `reels/<reel_id>/…` (§1). Nothing else should be written to
  the bucket.

### 6.3 Real uploads: verify first, with a test account

1. **Signed size and type.** A presigned PUT whose body is larger than the
   signed `Content-Length`, or whose `Content-Type` differs, must be refused
   by R2. The local fake enforces this; R2 itself is unverified. If R2 does
   not enforce it, the HEAD size check in processing still deletes oversized
   files, but storage is used until then.
2. A 1-hour URL expires: a PUT after expiry is refused.
3. Upload from a real Android phone on mobile data (the app streams the body
   from memory; files up to 150 MB).
4. `POST /v1/reels/{id}/upload-complete` moves the reel to `processing`.
   Killing the app before that call must still reach `processing` through
   `reels-reconcile-uploads` within 10–15 minutes.

### 6.4 Processing

- Push `backend/Dockerfile.media` to Artifact Registry (built and
  smoke-tested locally on 27 Nov, not pushed).
- Create a Cloud Run **job** `reels-process-media`:
  - 1 vCPU, 1 GiB, max 1 parallel task;
  - task timeout 20 minutes (the per-reel deadline is 15 minutes and the claim
    lease 20 minutes);
  - the same secrets as the API, plus `SIGHTENGINE_*` for moderation.
- **Trigger** (open decision): every 5 minutes via Cloud Scheduler, or
  started on demand by `upload-complete` (cheaper when idle). Each scheduled
  run is a container start.
- Apply hosted migrations **in order**:
  1. `20261123000100_reels_experiment`
  2. `20261127000100_reels_r2_media`
  3. `20261127000400_reels_processing_claims`
- Verify on real media:
  - a 1080p phone clip becomes 720p MP4 + poster + stills + manifest;
  - re-running is a no-op;
  - two overlapping job runs process each reel once;
  - a corrupt file fails with a reason code;
  - CPU time per reel (estimate: 30–60 vCPU-seconds).

### 6.5 Playback

- Presigned GET URLs (6 h for viewers, 15 min for moderators) for
  `playback.mp4` and `thumbnail.jpg`.
- Verify on Android with `video_player` (ExoPlayer):
  - first frame within about 1 s on 4G;
  - seeking and looping work (needs HTTP range requests, which R2 supports);
  - the next reel is preloaded;
  - playback stops on background or an incoming call;
  - "Try again" appears offline.
- **Known limit:** a feed left open more than 6 h holds expired URLs, and
  "Try again" fails until the feed is refreshed. Fix before launch if it
  matters: refresh the reel on a 403.

### 6.6 CDN and delivery

- **Today:** private bucket plus presigned URLs, with no edge cache. Egress is
  free on R2; every view costs a few Class B operations (about 2–5).
  Takedowns are immediate.
- **Later, only if views grow:** a second, public bucket holding only
  *published* `playback.mp4`/`thumbnail.jpg` behind a custom domain with
  Cloudflare cache, deleted on takedown (with a cache purge). This needs:
  - a domain;
  - a cache-purge token;
  - a change to `Playback()`.
  Not built.

### 6.7 Production configuration

| Setting | Value |
|---|---|
| `REELS_VIDEO_PROVIDER` | `r2` |
| `REELS_ENABLED` | `true`, **only after** 6.3–6.5 pass on staging |
| `R2_KEEP_ORIGINALS` | `false` |
| `REELS_MODERATION_FRAME_SECONDS` | `2` |
| `SIGHTENGINE_*` | Required. Without them every reel goes to human review, which is safe but needs staff. |
| App build | `--dart-define=DASHURI_REELS_ENABLED=true` in the same release |
| Mux | Leave every `MUX_*` empty (no Mux account is needed) |

- **Rollback:** set `REELS_ENABLED=false`. Media and rows stay; nothing is
  deleted.
- **Policy:** disclose Cloudflare as a processor in the privacy policy (DPDP).

## 7. Files

**Backend:**

- `backend/internal/adapters/r2/`: `sigv4.go`, `store.go`, `provider.go`,
  and tests with a signing S3 fake.
- `backend/internal/adapters/ffmpeg/`: `ffmpeg.go` and tests.
- `backend/internal/modules/reels/`: `ports.go` (`UploadRequest`,
  `SelfProcessing`, `MediaError`, `ErrProcessorUnavailable`, `Playback.URL`
  and `Format`), `service.go` (per-row providers, `CompleteUpload`),
  `moderation.go` (`ProcessMedia`), `dto.go`, `http.go`,
  `reels_r2_flow_integration_test.go`.
- `backend/internal/adapters/postgres/reels_repo.go`: media columns, and the
  purge query now selects `provider`.
- `backend/internal/app/wire_reels.go`, `backend/internal/jobs/reels.go`
  (`reels-process-media`), `backend/internal/platform/config/config.go`,
  `backend/.env.example`, `backend/Dockerfile.media`.

**Database and API:**

- `supabase/migrations/20261127000100_reels_r2_media.sql`
- `api/openapi/dashuri.v1.yaml`

**App:**

- `packages/features/reels`: `ReelPlayback.url`/`format`, upload sends size
  and type plus the signed headers, then calls upload-complete.
- `packages/network`: `uploadToSignedUrl(headers:)`.
