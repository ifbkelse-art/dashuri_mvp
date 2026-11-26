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
| Validation | Size (HEAD, then a bounded download). ffprobe checks: container in an allow-list, a video stream, ≤ 4096 px, 14.1–60.9 s. Rejections get a reason code: `file_too_large`, `invalid_media`, `unsupported_format`, `no_video_stream`, `duration_out_of_range`, `upload_missing`. | `adapters/r2` `Process`, `adapters/ffmpeg` |
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
- `Dockerfile.media` build: Docker was not running on the dev Mac.
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

## 6. Before turning R2 on (each needs founder approval)

1. Create a Cloudflare account and a private R2 bucket, plus an API token
   scoped to that bucket (Object Read & Write). Find out whether a card is
   required.
2. Test against the real bucket first: is the signed `Content-Length`
   enforced? Do presigned GETs play in ExoPlayer?
3. Build `Dockerfile.media`; create the Cloud Run job `reels-process-media`
   (1 vCPU, 1 GiB, max 1 task, timeout about 15 min). The trigger is an open
   decision (§4).
4. Apply migrations `20261123000100` and `20261127000100` to hosted Supabase.
5. Set `R2_*` secrets, `REELS_VIDEO_PROVIDER=r2`, and then `REELS_ENABLED`.
6. App: integrate `video_player` for MP4 playback (next phase).

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
