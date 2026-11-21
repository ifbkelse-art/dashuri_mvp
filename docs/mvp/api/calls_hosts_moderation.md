# Calls, Free Call Card, hosts and moderation (BE-calls)

This document covers the Go backend for paid calls, the Free Call Card (S4), host onboarding and earnings, and moderation in the first three minutes of a call (S7).
Contract sources: `api/openapi/dashuri.v1.yaml` and `docs/mvp/MVP_DECISIONS_AND_CONTRACT.md` §2.5 and §2.7.
All amounts are integers. Business refusals are 409 with `code: business_rule` and `rule: <name>`.

## Code map

| Area | Files |
|---|---|
| Calls lifecycle, metering, settlement | `backend/internal/modules/calls/` (`service.go`, `settle.go`, `timeline.go`, `metering.go`, `lifecycle.go`) |
| Stream Video adapter | `backend/internal/adapters/stream/` |
| Free Call Card | `backend/internal/modules/freecall/`, `backend/internal/adapters/playintegrity/` |
| Hosts | `backend/internal/modules/hosts/` (manual KYC provider in `ports.go`) |
| Moderation | `backend/internal/modules/moderation/`, `backend/internal/adapters/sightengine/` |
| Postgres | `backend/internal/adapters/postgres/{calls,freecall,hosts,moderation}_repo.go` |
| Wiring | `backend/internal/app/wire_{calls,freecall,hosts,moderation}.go` |
| Jobs | `backend/internal/jobs/calls.go` |
| Migration | `supabase/migrations/20261121000300_calls_moderation.sql` |

## Endpoints

### Calls

| Method | Path | Notes / errors |
|---|---|---|
| POST | /v1/calls (Idempotency-Key) | `{host_user_id}` → CallSession 201 (`ringing`). Refusals: `not_age_eligible`, `account_restricted`, `self_call`, `host_unavailable`, `blocked`, `caller_in_call`, `host_busy`, `insufficient_diamonds`. It reserves 120 s worth of Diamonds, or the whole available balance if smaller (at least 60 s is required). |
| GET | /v1/calls/history | `?cursor&limit` → `{items: [CallSession], next_cursor}`. Lists your own calls, newest first. |
| GET | /v1/calls/{id} | Participants only; anyone else gets 404. A ringing call older than 30 s is turned into `missed` when it is read. |
| POST | /v1/calls/{id}/accept | Receiver only (others get 403 `not_receiver`). `call_expired` after 30 s; `illegal_call_transition` otherwise. Repeating the request returns the same result. |
| POST | /v1/calls/{id}/decline | Receiver only. Releases the reservation. |
| POST | /v1/calls/{id}/end (Idempotency-Key) | `{reason: hangup\|report\|low_balance\|other}`. Settles once. Repeating the request returns the settled session. |
| POST | /v1/calls/{id}/credentials | Participants only, in phase accepted, connecting, active or paused (otherwise `call_not_joinable`). Moves the call from `accepted` to `connecting`. Returns `{provider:"stream", provider_call_id, user_token, expires_at, api_key, call_type:"default"}`. The token is valid for 1 h and covers only `default:<call id>`. |
| POST | /v1/webhooks/video/stream | Raw Stream webhook. Invalid signature → 401 `invalid_signature`. Unknown provider → 422. Otherwise 204. |

`CallSession` gains these fields: `peer {user_id, display_name, photo_url}`, `started_at` (the connected time), `moderation_window_ends_at`, `created_at` and `ended_at`. `photo_url` is currently always null (see "Open items").

`end_reason` values: `hangup`, `report`, `low_balance`, `other`, `declined`, `missed`, `connect_timeout`, `timeout`, `moderation`, `free_call_limit`, `provider_ended`, `provider_error`.

Realtime events:
- `call.updated` goes to `user:<caller>` and `user:<receiver>`, each from that user's own perspective. It also goes to `call:<id>` from the **caller's** perspective, with extra `caller_user_id` and `receiver_user_id` fields, so a client on `call:<id>` should derive its role from those fields.
- `call.low_balance {seconds_remaining}` and `call.moderation_ended {call_id}` go to `call:<id>`.

### Moderation (S7)

| Method | Path | Notes |
|---|---|---|
| POST | /v1/calls/{id}/moderation-frames | `{image_base64, captured_at}` → 202 `{accepted}`. Participants only. The image must be a JPEG of at most 200 KB after decoding (the body limit for this route is 300 KB). The call must be active and `now < moderation_window_ends_at`; otherwise `moderation_window_closed`, or `call_not_active` before the call has connected. When `MODERATION_ENABLED` is true but Sightengine is not configured: 503 `moderation_not_configured`. When `MODERATION_ENABLED` is false: `{accepted:false}`. A flagged frame ends the call (reason `moderation`), opens a priority-1 automated `safety.reports` case (category `nudity`, no reporter) and stores evidence metadata in `moderation.evidence`. |
| GET | /v1/admin/moderation/queue | Moderator or admin. Lists open and in-review cases by priority, then age, with `evidence_count`. |
| POST | /v1/admin/reports/{id}/decisions (Idempotency-Key) | `dismiss\|warn\|restrict_calls\|suspend\|ban\|escalate_legal` → `safety.enforcement_actions`, an account status change (restricted / suspended / banned / suspended; a status is never lowered), the host taken offline, a `moderation.decisions` row and an audit event. Refusals: `already_decided`; 403 `self_review` for a case about yourself. |
| POST | /v1/admin/appeals/{id}/decisions (Idempotency-Key) | `upheld\|overturned`. Must be decided by a different reviewer than the one who made the original decision (`different_reviewer_required`). Overturning expires the enforcement action and restores `active` unless another enforcement action is still in force. |

The classification threshold is `moderation.DefaultFlagThreshold = 0.6`, applied to the highest of `sexual_activity`, `sexual_display` and `erotica`. It can be changed through `Deps.Threshold`.

### Free Call Card (S4)

| Method | Path | Notes |
|---|---|---|
| GET | /v1/free-call/card | `available\|used\|not_eligible\|unavailable_on_platform`. Send the header `X-Client-Platform: android\|ios`; iOS gets `unavailable_on_platform`. |
| POST | /v1/free-call/requests (Idempotency-Key) | `{play_integrity_token, platform?}` (`platform` may also come from the `X-Client-Platform` header). Errors: `free_call_unavailable_on_platform`, `integrity_check_failed`, `not_age_eligible`, `account_restricted`, `phone_required`, `card_already_used`, `device_already_used`, `caller_in_call`; 503 `integrity_not_configured` / `free_call_disabled`. Returns `matched` with `call_id`, or `no_host_available` (in which case the card stays available). |
| GET | /v1/free-call/requests/{id} | Own requests only. |

Rules:
- **Phone binding.** The phone hash is `sha256(auth.users.phone)`, computed in the database by `freecall.phone_hash()`, so the phone number never reaches the API.
- **Device binding.** The device binding is the SHA-256 of the Play Integrity `requestHash` (standard request) or `nonce` (classic request). **The app must set that field to `base64url(sha256(ANDROID_ID))`.**
- **Verdict checks.** The server requires `PLAY_RECOGNIZED`, `MEETS_DEVICE_INTEGRITY`, the matching package name and a token less than 10 minutes old.
- **Matching.** The host is chosen at random among approved, available, opted-in hosts who are not in a call and not blocked either way, using `FOR UPDATE SKIP LOCKED`. The host's IST daily counter row is locked `FOR UPDATE` and must be below 20.
- **The call.** `is_free_call=true`, rate 0, with a 60 s server cap (`end_reason = free_call_limit`).
- **Host compensation.** `FreeCallCompensation` (2,000 Beans, key `free_call_comp:<call id>`) is posted once, either when the call reaches 60 s or when it ends after having been active.
- **Card returned.** If a free call never connects (declined, missed or failed), the card and the host's daily slot are given back.

### Hosts

| Method | Path | Notes |
|---|---|---|
| GET | /v1/host | HostStatus plus `today_earned_beans`, `today_calls` and `level`. `not_applied` if the user has never applied. |
| POST | /v1/host/application (Idempotency-Key) | Requires age eligibility. Creates the host row as `applied`; the host role is added only on approval. Refusal: `already_applied`. |
| POST | /v1/host/kyc/sessions (Idempotency-Key) | Manual provider: the session is `started`, the host becomes `kyc_pending` with `kyc_state=in_progress`. Repeating the request returns the open session. Refusals: `host_not_applied`, `kyc_already_approved`. |
| PUT | /v1/host/availability | Approved hosts only (`host_not_approved`). Refused during a live call (`in_call`). Going online also records a heartbeat. |
| POST | /v1/host/availability/heartbeat | 204. |
| PUT | /v1/host/rate | `economy.ValidateRate` with the host's level → `rate_outside_level_limits`. |
| PUT | /v1/host/free-call-opt-in | Approved hosts only. |
| GET | /v1/host/earnings | Beans held, available and pending payout, `available_inr_paise`, `today_earned_beans` and `today_calls`. |
| POST | /v1/admin/hosts/{userId}/kyc-decision | Moderator or admin. `{decision: approve\|reject, date_of_birth, reason}`. Approval requires the person to be at least 18 years old (IST); it sets `date_of_birth`, `age_method='kyc_verified'`, `age_eligible`, the `host` role, host state `approved`, and writes an audit event. Rejection sets `kyc_state=rejected` and the state back to `applied`. |

## Lifecycle and billing

- **Live timeline.** The timeline comes only from webhooks (`calls.Timeline`). A participant counts as live while joined and publishing video. If Stream sent no track events for the call, joining counts as publishing.
- **Billing start.** The first moment both participants are live moves the call to `active`, sets `connected_at`, and sets `moderation_window_ends_at = connected_at + 180 s`.
- **Pauses.** A gap of 10 s or more pauses billing (phase `paused`); shorter gaps are billed as blips.
- **Settlement.** Settlement runs in **one transaction**:
  1. Lock the call row.
  2. Compute `BillableSeconds`.
  3. Compute ⌊rate × s / 60⌋, capped by the reservation and the balance, and spend promotional Diamonds first.
  4. Post `ledger.CallSettlement`.
  5. Insert the `calls.settlements` row.
  6. Mark the reservation settled or released.
  7. Insert `ledger.xp_events` (source `call:<id>`, 1 XP per Bean).
  8. Update the call row.

  The provider `EndCall` and the realtime publish happen after commit. Concurrent `/end` requests and job runs settle exactly once.
- **Worked example.** 65 s at 4,000 D/min = 4,333 D charged and 2,599 Beans to the host (tested).
- **Reservation and low balance.** While a call is active, the reservation is extended in 120 s windows when less than 60 s of it remains. `call.low_balance` is sent once when 30 s or less is left, and the call ends at zero (`low_balance`).

## Jobs (`worker <job>`)

| Job | Schedule | What it does |
|---|---|---|
| `settle-stale-calls` | every 1 min; sweeps every 5 s for 55 s | ringing > 30 s → missed; not active 45 s after accept → failed (no charge); active → paused after 10 s; nobody live and no events for 90 s → ended (`timeout`) and settled; also extends reservations, sends the low-balance warning and enforces the free-call cap |
| `mark-offline-hosts` | every 1 min | takes hosts offline after 90 s without a heartbeat (hosts in a call are skipped) |
| `moderation-missing-frames` | every 1 min | a participant who sent no frame for 60 s inside the window gets an automated priority-2 review case (`missing_frames`), at most once per call and participant; the call is not ended |
| `release-bean-holds` | hourly | `BeanRelease` for Bean credits held more than 7 days, key `bean_release:<source entry>`, capped by the current held balance |

## Stream Video setup

1. Create a Stream Video app at getstream.io and use the India-nearest region.
2. Set `STREAM_API_KEY` and `STREAM_API_SECRET` in Secret Manager. The secret signs server and user JWTs and verifies webhooks. If either is empty, every call endpoint returns 503 `video_not_configured`.
3. In the Stream dashboard, open Video → Webhooks and set the webhook URL to `https://<api-host>/v1/webhooks/video/stream`. Enable at least these events:
   - `call.session_participant_joined`
   - `call.session_participant_left`
   - `call.ended`
   - `call.session_ended`
   - track published/unpublished, if offered
4. Call type `default`: keep the "join call" permission limited to call members. The server creates every call with two members and `limits.max_participants = 2`, and user tokens carry `call_cids` limited to that one call.
5. Signature check: the server compares `X-Signature = hex(HMAC-SHA256(body, secret))` in constant time and checks `X-Api-Key`. The event id is `X-Webhook-Id`, or the SHA-256 of the body if that header is missing; duplicate events are ignored.

## Configuration

| Variable | Used for |
|---|---|
| `STREAM_API_KEY`, `STREAM_API_SECRET` | Stream Video (required in staging and production) |
| `MODERATION_ENABLED` (default true), `SIGHTENGINE_API_USER`, `SIGHTENGINE_API_SECRET` | Frame checks (`nudity-2.1`) |
| `FREE_CALL_ENABLED` (default true) | Free Call Card |
| `GOOGLE_APPLICATION_CREDENTIALS`, `PLAY_PACKAGE_NAME` | Play Integrity `decodeIntegrityToken` (service account needs the Play Integrity API enabled and the app linked in Play Console) |
| `SUPABASE_URL`, `SUPABASE_REALTIME_SERVICE_KEY` | Realtime events (no events are sent when these are unset) |

## Migration `20261121000300_calls_moderation.sql`

- `calls.calls`: adds `low_balance_notified_at` and `free_call_compensated`, plus indexes.
- `safety.reports`: `reporter_id` becomes nullable; adds `source user|automated` and `automated_reason`, a check that user reports have a reporter, and a unique automated case per (call, target, reason).
- New tables `moderation.decisions` (append-only) and `freecall.requests`, with RLS, `service_all` and grants as for the other tables.
- New definer function `freecall.phone_hash(uuid)`.

## Open items

- `peer.photo_url` is null. It needs a signed-URL helper from BE-identity (`supabase.PhotoStorage`).
- Flagged frames are not stored as images. Only metadata is stored (`storage_ref = frame_checks/<id>`) because the moderation-evidence bucket upload (`EvidenceStore`) is not wired yet. Retention is set to 180 days pending legal review (PRO-REVIEW).
- It is not confirmed that Stream sends track-published webhooks. The timeline works with or without them.
