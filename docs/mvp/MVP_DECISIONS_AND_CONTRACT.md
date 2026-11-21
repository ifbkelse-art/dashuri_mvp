# Dashuri MVP — decisions and contract additions (2026-11-21)

This document is the single source of truth for the MVP build in `dashuri_mvp`.
It extends `docs/architecture/*` and `api/openapi/dashuri.v1.yaml`. Every API
change here is **additive within v1**.

## 1. Founder decisions confirmed on 2026-11-21

| # | Topic | Decision | Supersedes / resolves |
|---|---|---|---|
| F1 | Payment rail for Diamonds | **Both rails.** Google Play Billing is the default. A server-verified **Cashfree PG** adapter sits behind config flags (`CASHFREE_ENABLED` on the server, `DASHURI_CASHFREE_ENABLED` in the app). The ledger is the same for both. | Design D-01; amends ADR-010 (see ADR-011) |
| F2 | Video provider | **Stream (getstream.io) Video**, as already planned in ADR-005. | Brief's ZEGOCLOUD mention |
| F3 | Product model | **Host marketplace** from the docs and designs. "Matchmaking" = Free Call Card random match (S4). | Brief's "random stranger" wording |
| F4 | Location | **Coarse city, opt-in.** The user picks a city or detects it once; the server maps coordinates to the nearest supported city and **never stores coordinates**. Used for display ("Pune") and the discovery filter only. | `flutter-architecture.md` "location not created" |
| F5 | Chat | **Go API + Supabase Realtime** (no Stream Chat). | — |
| F6 | UI | Implement the 19 Nov design handoff (`design/Dashuri_Design`), responsive across compact, medium and expanded widths. | — |

### Engineering defaults for still-open design decisions

These are reversible defaults, chosen so the MVP is usable. Each is a config value or a small code change.

| Open item | MVP default | Where to change |
|---|---|---|
| D-02 Google sign-in | **Phone OTP only** (architecture). The Google button is not shown. | `feature_auth` |
| D-03 Gender | Options: man, woman, non_binary, prefer_not_to_say. **Never shown publicly.** | `identity.profiles.gender` |
| D-04 Account roles | One account can be customer and host. "Become a host" is in Profile and Settings. | `feature_host` |
| D-05 Free Call Card lifecycle | Single use, no expiry, no re-issue. | `freecall` |
| D-06 Discovery sort | `recommended` (live heartbeat first, then level), `rate_low`, `rate_high`. | `discovery` |
| D-07 ₹ approximation | Shown as "≈ ₹x/min" from the cheapest active package's paise-per-Diamond, labelled approximate. Supplied by the server (`approx_paise_per_diamond`). | `purchases` |
| D-08 Last seen | "Offline" only (no relative last-seen, for privacy). | `discovery` |
| D-09 Safety-check indicator | A small "Safety check active" chip during the first 3 minutes. | `feature_video_call` |
| D-10 In-call top-up | Not in the MVP. The low-balance banner links to the wallet after the call. | — |
| D-11 Post-call rating | **Not in the MVP** (scale and use unresolved). The summary screen has no rating. | — |
| D-13 Interruption threshold | 10 s (existing technical assumption). | `economy.rule_sets` |
| D-14 Package prices | Seeded from the simulation prices and marked `provisional`. | migration seed |
| D-15 Chat model | Free text, 1,000 characters, no media, read markers, no typing indicator. | `chat` |
| D-16 Levels | Thresholds from the proposal (P12), display only. | `economy.rule_sets` |
| D-17/D-18/D-19 Payouts | Withdrawal requests work; payouts stay **disabled** (`PAYOUTS_ENABLED=false`, R3-7). The UI shows H21 "Withdrawals unavailable". | `payouts` |
| D-20 Report window | 24 hours after a call ends. | `safety` |
| D-21 Deletion and balances | Deletion is refused (409 `pending_balance_or_payout`) while Beans are held, available or pending payout. Unspent Diamonds are forfeited after explicit confirmation. There is a 7-day grace period. | `accounts` |
| D-22 Support | Email link (`support_email` from server config) plus an in-app grievance form that creates a report of category `other`. | `settings` |

## 2. Contract additions (v1, additive)

All amounts are integers; snake_case JSON; problem+json errors as before.

### 2.1 Accounts, profile, onboarding

`AccountStatus` gains:
- `profile_complete: bool`: display name and gender set.
- `rules_accepted: bool`: community rules accepted (current version).
- `is_host: bool` and `host_state: string|null` (`applied|kyc_pending|approved|suspended`).

`Profile` gains (own profile only, via `GET /v1/me/profile`): `gender`, `city`.
Public profiles (`GET /v1/profiles/{userId}`) gain `city` (coarse) but **never** `gender`.
`city` is `{ "id": "pune", "name": "Pune", "state": "Maharashtra" } | null`.

`UpdateProfileRequest` gains optional `gender` (enum above) and `city_id` (string or null to clear).

New:
| Method | Path | Request | Response | Idem |
|---|---|---|---|---|
| POST | /v1/me/rules-acceptance | `{ "version": "2026-11" }` | AccountStatus | |

### 2.2 Location (coarse city, opt-in)

| Method | Path | Request | Response | Notes |
|---|---|---|---|---|
| GET | /v1/locations/cities | `?query=` (optional, ≥ 1 char) | `{ "items": [City] }` | Curated list of supported Indian cities |
| POST | /v1/locations/resolve | `{ "latitude": 18.52, "longitude": 73.85 }` | `City` | Nearest supported city within 75 km; otherwise 404 `no_supported_city_nearby`. **Coordinates are not stored or logged.** The client rounds them to 2 decimals before sending. |

### 2.3 Discovery

`GET /v1/discovery/hosts` gains optional query parameters: `language` (ISO 639-1, e.g. `hi`), `city_id`, `sort` (`recommended|rate_low|rate_high`).
`HostCard` gains `city` (City|null), `age` (int, from the verified DOB, nullable), `is_verified` (KYC approved) and `availability` adds `offline`.
`GET /v1/discovery/hosts/{userId}` → `HostCard` plus `bio` (host detail for C07–C09), with the same block rules (404 when blocked either way).
`GET /v1/discovery/summary` → `{ "online_count": int }`.

### 2.4 Purchases: two rails

`GET /v1/purchases/packages` → `DiamondPackageList` gains:
- per item: `price_paise` (int), `label` (string), `badge` (string|null), `provisional` (bool);
- top level: `rails: ["google_play", "cashfree"]` (the rails enabled on the server), `approx_paise_per_diamond_milli` (int, ₹ estimate basis × 1000).

New (Cashfree; 503 `rail_disabled` when `CASHFREE_ENABLED=false`):
| Method | Path | Request | Response | Idem |
|---|---|---|---|---|
| POST | /v1/purchases/cashfree/orders | `{ "product_id": "…" }` | `CashfreeOrder` (201) | ✓ |
| GET | /v1/purchases/cashfree/orders/{orderId} | — | `CashfreeOrder` | |
| POST | /v1/webhooks/cashfree | raw (Cashfree PG webhook v2025) | 204 | signature |

`CashfreeOrder`:
```json
{ "order_id": "dsh_…", "product_id": "…", "amount_paise": 119900, "diamonds": 54000,
  "payment_session_id": "…", "environment": "sandbox|production",
  "state": "created|pending|credited|failed|expired", "diamonds_credited": 0 }
```
Rules:
- The server creates the order with Cashfree using server-held credentials. `order_amount` comes from the server's package table, never from the client.
- **Crediting happens only after the server has verified payment with Cashfree**: either a signature-verified webhook (`x-webhook-signature` = base64(HMAC-SHA256(timestamp + raw body, client secret))) or a server-to-server `GET /orders/{id}` with `order_status = PAID` and a matching amount and currency. `GET …/orders/{orderId}` triggers that server-side re-check, so a lost webhook still credits.
- Ledger key: `purchase_credit:cashfree:<order_id>`; `commerce.purchases.purchase_token_hash = sha256("cashfree:" + order_id)`. Exactly once.

### 2.5 Calls and moderation (S7)

`CallSession` gains `peer` (`{user_id, display_name, photo_url}`), `started_at` (connected time, nullable), `moderation_window_ends_at` (nullable).

New:
| Method | Path | Request | Response | Notes |
|---|---|---|---|---|
| POST | /v1/calls/{callId}/moderation-frames | `{ "image_base64": "<jpeg ≤ 200 KB>", "captured_at": RFC3339 }` | `{ "accepted": true }` 202 | Only during the first 180 s after `active`; afterwards 409 `moderation_window_closed`. Each participant submits frames of **their own outgoing camera** every 20 s. Server classifies with `NudityClassifier` (Sightengine adapter). If flagged: end the call (reason `moderation`), open a priority-1 report case and store evidence. If a participant sends no frames for 60 s inside the window, the server queues a review (it does not end the call). |
| GET | /v1/calls/history | cursor, limit | Page\<CallSession\> | Own calls (host H22, customer history) |

### 2.6 Chat

`Conversation` gains `peer` (`{user_id, display_name, photo_url}`), `last_message` (ChatMessage|null), `unread_count` (int).
New: `POST /v1/conversations/{id}/read` → 204 (marks read up to now).
Messaging restriction (CH04): `messaging_not_allowed` when the receiver's `who_can_message = past_call_partners` and the pair has no ended call with billed seconds > 0.
Filter (CH05): `message_rejected` with `reason: contact_details` when the body contains phone numbers, UPI IDs, emails or links.

### 2.7 Hosts

`HostStatus` gains `kyc_state`, `free_call_opt_in`, `today_earned_beans`, `today_calls`.
KYC vendor is unresolved: `POST /v1/host/kyc/sessions` uses the `KYCProvider` port. The MVP adapter is **`manual`**: the session moves to `in_progress`, and a moderator decides with
`POST /v1/admin/hosts/{userId}/kyc-decision` `{ "decision": "approve|reject", "date_of_birth": "YYYY-MM-DD", "reason": "…" }` (moderator role, audited). Approval requires DOB ≥ 18 years.

### 2.8 Realtime events (unchanged channels)

`user:<id>`: `call.updated` (incoming ring for hosts), `chat.message` `{conversation_id}`, `wallet.updated`, `notification.created`.
`call:<id>`: `call.updated`, `call.low_balance {seconds_remaining}`, `call.moderation_ended`.
