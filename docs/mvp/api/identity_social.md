# Identity and social API (BE-identity)

New or changed endpoints for accounts, levels, location, discovery, chat, safety and notifications.
Everything here is additive within v1. All routes need `Authorization: Bearer <Supabase access token>`.
Errors are `application/problem+json`; business refusals are **409** with `code: "business_rule"` and `rule: <name>`.
Validation errors are **422** with `errors: [{field, reason}]`. Without a database every route returns 503 `database_unavailable`.
Lists use `?cursor=&limit=` (1–100, default 20) and return `{items, next_cursor}`; `next_cursor` is omitted on the last page. A tampered cursor returns 422 (`cursor: invalid`).

## Accounts

### GET /v1/me → AccountStatus
```json
{ "user_id": "…", "age_eligible": true, "is_host": false, "host_state": null,
  "profile_complete": true, "rules_accepted": true, "restriction": null }
```
- `profile_complete`: display name and gender are set.
- `rules_accepted`: the account accepted the current rules version (`2026-11`).
- `is_host`: `host_state == "approved"`. `host_state`: `applied|kyc_pending|approved|suspended|null`.
- `restriction`: `null`, `"restricted"`, or `"under_18"` (restricted after an under-18 declaration).

### POST /v1/me/rules-acceptance
Request `{ "version": "2026-11" }` → 200 AccountStatus. Errors: 409 `rules_version_outdated` (not the current version), 422 `version: required`.

### GET /v1/me/profile → Profile (own)
```json
{ "user_id": "…", "display_name": "Priya", "bio": "Love music", "languages": ["hi","en"],
  "photo_urls": ["https://…signed…"], "is_host": false, "level": 2,
  "city": { "id": "pune", "name": "Pune", "state": "Maharashtra" }, "gender": "woman" }
```
404 until the profile has been created with PATCH. Own photos include `pending_review` ones. Photo URLs are signed and valid for 1 hour.

### PATCH /v1/me/profile
All fields optional: `display_name` (1–40 chars, trimmed), `bio` (≤ 300 chars; `null` clears), `languages` (≤ 10 ISO 639-1 codes; lowercased and de-duplicated), `gender` (`man|woman|non_binary|prefer_not_to_say`), `city_id` (a supported city id; `null` clears).
```json
{ "display_name": "Priya", "gender": "woman", "city_id": "pune", "languages": ["hi","en"] }
```
→ 200 Profile. The first PATCH creates the profile and needs `display_name`.
Errors: 409 `profile_text_rejected` (display name or bio contains a phone number, UPI ID, email or link); 422 `display_name: required|too_long|invalid_characters`, `bio: too_long`, `languages: invalid_value|too_many`, `gender: invalid_value`, `city_id: invalid_value|unknown_city`.

### GET /v1/profiles/{userId} → Profile (public)
Same shape as the own profile, but **never includes `gender`** and only shows approved photos. 404 `not_found` when the user doesn't exist, isn't active, has no profile, or **either user has blocked the other**.

### POST /v1/me/photos/upload-tickets (Idempotency-Key)
Request `{ "content_type": "image/jpeg" }` (`image/jpeg|image/png|image/webp`) → 201
```json
{ "photo_id": "…", "upload_url": "https://<project>.supabase.co/storage/v1/object/upload/sign/profile-photos/<user>/<photo>.jpg?token=…",
  "expires_at": "2026-11-21T12:00:00Z", "status": "pending_review" }
```
The app uploads the file to `upload_url` with an HTTP PUT. The photo stays private and `pending_review` until it is moderated.
Errors: 409 `photo_limit_reached` (6 pending or approved photos); 503 `storage_not_configured` (the server has no `SUPABASE_STORAGE_SERVICE_KEY`).

### GET /v1/me/age → `{ "eligible": false, "method": null, "declared": false }`

### POST /v1/me/age/declaration (Idempotency-Key)
Request `{ "date_of_birth": "1998-04-12" }` → 200 `{ "eligible": true, "method": "self_declared", "declared": true }`. Age is computed on the current date in India (IST).
Errors: 409 `under_18`: the date of birth is still recorded, and the account becomes `restricted` with `age_eligible=false`. 409 `declaration_locked`: a date of birth was already declared or verified. 422 `date_of_birth: required|invalid_date|in_future|too_old`.

### GET / PUT /v1/me/consents
PUT `{ "analytics": true, "marketing": false }` (both required) → `{ "analytics": true, "marketing": false, "updated_at": "…" }`. GET returns everything off by default.

### POST /v1/me/deletion-requests (Idempotency-Key) → 202
`{ "request_id": "…", "status": "received", "scheduled_for": "<now + 7 days>" }`. If a request is already open, that request is returned.
409 `pending_balance_or_payout`: the account has Beans held, available or pending payout, an open withdrawal, or a live call.

### POST /v1/me/data-exports (Idempotency-Key) → 202 `{ "request_id": "…", "status": "received" }`
If an export is already open, that export is returned.

## Levels
### GET /v1/me/level
`{ "level": 3, "lifetime_xp": 110000, "current_level_xp": 100000, "next_level_xp": 250000 }`. `next_level_xp` is null at the top level. The thresholds come from `economy.Rules`.

## Location (coarse, opt-in; coordinates are never stored or logged)
### GET /v1/locations/cities?query=pun
`{ "items": [ { "id": "pune", "name": "Pune", "state": "Maharashtra" } ] }`. The query matches name, state or id prefix, case-insensitively, up to 40 characters. Without a query, all supported cities are returned.

### POST /v1/locations/resolve
Request `{ "latitude": 18.52, "longitude": 73.85 }` (the client rounds to 2 decimals) → 200 City.
Errors: 404 `no_supported_city_nearby` (no supported city within 75 km, by haversine distance); 422 `latitude|longitude: required|out_of_range`.

## Discovery
### GET /v1/discovery/hosts?language=hi&city_id=pune&sort=recommended&cursor=&limit=20
Lists approved hosts with active accounts that are **available** (`is_available` and a heartbeat in the last 90 s) or **busy** (in a live call). The caller and blocks in either direction are excluded.
`sort`: `recommended` (available first, then level high → low), `rate_low`, `rate_high`. The keyset cursor is tied to its sort.
```json
{ "items": [ { "user_id": "…", "display_name": "Asha", "photo_url": "https://…", "languages": ["hi"],
  "level": 2, "rate_per_minute": 800, "availability": "available",
  "city": { "id": "pune", "name": "Pune", "state": "Maharashtra" }, "age": 27, "is_verified": true } ],
  "next_cursor": "…" }
```
`age` comes only from a KYC-verified date of birth (otherwise null). `is_verified` means KYC is approved. Errors: 422 `language|city_id|sort|limit|cursor`.

### GET /v1/discovery/hosts/{userId} → HostCard + `bio`
This also returns offline hosts (`availability: "offline"`). 404 when the user is not an approved host or either user has blocked the other.

### GET /v1/discovery/summary → `{ "online_count": 42 }`
The number of hosts the caller would see in the list (available or busy).

## Chat
`Conversation`:
```json
{ "id": "…", "peer_user_id": "…", "peer_display_name": "Bina",
  "peer": { "user_id": "…", "display_name": "Bina", "photo_url": null },
  "last_message": { "id": "…", "conversation_id": "…", "sender_id": "…", "body": "hello", "sent_at": "…" },
  "last_message_preview": "hello", "unread_count": 3, "updated_at": "…" }
```
- **GET /v1/conversations**: newest activity first. Conversations where either user has blocked the other are hidden.
- **POST /v1/conversations** (Idempotency-Key) `{ "peer_user_id": "…" }` → 201 Conversation. If the pair already has a conversation, that one is returned (one per pair; `user_a < user_b`).
- **GET /v1/conversations/{id}/messages**: newest first. 404 if the caller is not a participant.
- **POST /v1/conversations/{id}/messages** (Idempotency-Key) `{ "body": "hi" }` → 201 ChatMessage. The body is trimmed, 1–1,000 characters, text only. After commit the server publishes `chat.message {conversation_id}` on `user:<recipient>` and sends a push without the message text.
- **POST /v1/conversations/{id}/read** → 204. Marks the conversation read up to now.
- **GET / PUT /v1/me/messaging-privacy** `{ "who_can_message": "everyone|past_call_partners" }`.

Refusals for start and send:
- 409 `not_age_eligible`: the caller hasn't passed the 18+ check.
- 409 `account_restricted`: the caller is restricted.
- 409 `blocked`: either user blocked the other.
- 409 `messaging_not_allowed`: the receiver is not eligible, is restricted, or has `past_call_partners` set and the pair has no ended call with `billed_seconds > 0`.
- 404: the peer or conversation doesn't exist, or the caller is not a participant.
- 422 `peer_user_id: self`.

Contact-detail filter (send only):
```json
{ "type": "…/message_rejected", "title": "Conflict", "status": 409, "code": "business_rule",
  "rule": "message_rejected", "reason": "contact_details",
  "errors": [ { "field": "body", "reason": "contact_details" } ] }
```

## Safety
- **POST /v1/reports** (Idempotency-Key) `{ "target_user_id": "…", "category": "nudity", "call_id": "…", "details": "…" }` → 201 `{ "report_id": "…", "status": "open" }`.
  - Priority is 1 for `nudity` and `minor_safety`, and 3 for other categories. Each report also writes an `audit.events` row (no free text).
  - With `call_id`: the caller must be a participant (otherwise 404), and the target must be the other participant (otherwise 422 `target_user_id: not_call_participant`).
  - The call must be live or have ended at most 24 h ago; otherwise 409 `report_window_closed`.
  - Other errors: 404 unknown target; 422 `target_user_id: self`.
  - Replaying the same Idempotency-Key returns the same receipt.
- **POST /v1/blocks** (Idempotency-Key) `{ "user_id": "…" }` → 201 `{ "user_id", "display_name", "blocked_at" }`. Blocking twice is idempotent. A block hides both users from each other in discovery, profiles and chat. It **does not end a live call by itself**. Errors: 404 unknown user; 422 self.
- **GET /v1/blocks**: newest first. **DELETE /v1/blocks/{userId}** → 204 (idempotent).
- **GET /v1/me/enforcement** → `{ "id", "action", "reason", "created_at", "appealable", "expires_at", "appeal_status" }` items.
- **POST /v1/appeals** (Idempotency-Key) `{ "enforcement_id": "…", "statement": "…" }` (≤ 2,000 characters) → 201 `{ "appeal_id", "status": "open" }`. Errors: 404 not your enforcement; 409 `not_appealable`; 409 `appeal_exists` (one appeal per enforcement).

## Notifications
- **PUT /v1/me/devices** `{ "token": "<fcm token>", "platform": "android" }` → 204. If the token was registered to another account, it moves to the caller.
- **DELETE /v1/me/devices/{token}** → 204 (idempotent).
- **GET /v1/notifications**: inbox, newest first (`InboxItem` with `read_at`).
- **POST /v1/notifications/{id}/read** → 204. 404 if the item isn't the caller's.
- Server side, `notifications.Notifier` stores the inbox item, publishes `notification.created {notification_id, kind}` on `user:<id>`, and pushes through FCM HTTP v1. Tokens that FCM reports as `UNREGISTERED` are removed. Pushes for `incoming_call` are data-only, high priority and have a 30 s TTL. Without `GOOGLE_APPLICATION_CREDENTIALS`, the push is skipped and logged at debug level.

## Server configuration
| Variable | Use |
|---|---|
| `SUPABASE_URL` + `SUPABASE_STORAGE_SERVICE_KEY` | Sign upload and read URLs for the private `profile-photos` bucket. If either is missing, photo uploads return 503 and photos are omitted. |
| `GOOGLE_APPLICATION_CREDENTIALS`, `FCM_PROJECT_ID` | FCM push. The project id falls back to the service account's `project_id`. |
| `SUPABASE_REALTIME_SERVICE_KEY` | `chat.message` and `notification.created` hints. |
