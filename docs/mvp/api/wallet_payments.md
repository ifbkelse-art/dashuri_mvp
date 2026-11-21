# Wallet, purchases, payouts and finance (BE-money)

Go modules: `backend/internal/modules/{wallet,purchases,payouts,admin}`. Adapters:
`internal/adapters/googleplay` (Android Publisher v3 + Pub/Sub OIDC), `internal/adapters/cashfree`
(Cashfree PG), `internal/adapters/postgres/{wallet,purchases,payouts,admin}_repo.go`. Jobs:
`internal/jobs/money.go`. Migration: `supabase/migrations/20261121000400_money.sql`.

Every Diamond credit is `ledger.PurchaseCredit` + a `commerce.purchases` row + an XP event
(8 × Diamonds) in **one transaction**, exactly once per purchase token / order (unique token
hash, ledger idempotency key, row locks).

## Endpoints

| Method | Path | Notes |
|---|---|---|
| GET | /v1/wallet | `WalletSummary` from the ledger projection. `available_diamonds = purchased + promotional − active reservations` (never < 0). |
| GET | /v1/wallet/entries | `?cursor&limit` (1–100). One item per journal entry and currency, newest first; `id` = journal entry id, `kind` = entry type, signed `amount`, `reference` (purchase/call/withdrawal id), **additive** `description` (e.g. "Diamonds purchased", "Video call", "Withdrawal requested"). Internal moves between a user's own Bean buckets show the change in withdrawable Beans. |
| GET | /v1/purchases/packages | Items with `price_paise`, `label`, `badge`, `provisional`; top level `rails` (`google_play` when Play credentials and package name are set, `cashfree` when `CASHFREE_ENABLED`) and `approx_paise_per_diamond_milli` = ⌊price × 1000 ÷ diamonds⌋ of the lowest-price active package (D-07). |
| POST | /v1/purchases/google-play | Idempotency-Key. `{product_id, purchase_token, order_id?}` → `PurchaseVerification {purchase_id, status: credited\|pending\|rejected, diamonds_credited}`. Errors: 409 `product_unknown`, `purchase_token_invalid`, `purchase_already_used_by_other_account` (token bound to another user, or `obfuscatedExternalAccountId` ≠ sha256(user id) hex); 503 `play_not_configured`, `play_unavailable`. |
| POST | /v1/webhooks/google-play/rtdn | Pub/Sub push. 204. 401 on a bad OIDC token. Deduped by message id. |
| POST | /v1/purchases/cashfree/orders | Idempotency-Key. `{product_id}` → `CashfreeOrder` (201). 409 `phone_required`, `product_unknown`; 503 `rail_disabled`, `cashfree_not_configured`, `cashfree_unavailable`. |
| GET | /v1/purchases/cashfree/orders/{orderId} | Owner only (404 otherwise). A non-final order is re-checked with Cashfree server-to-server and credited when `PAID` with matching amount and `INR`. |
| POST | /v1/webhooks/cashfree | Cashfree PG webhook. 204; 401 on a bad/stale signature; 503 when disabled/unconfigured (Cashfree retries). |
| POST | /v1/host/withdrawals | Host role, Idempotency-Key. **503 `payouts_not_enabled` first while `PAYOUTS_ENABLED=false`** (no Beans move). When enabled: 409 `below_minimum_withdrawal` (< 100,000 Beans), `account_restricted`, `kyc_required`, `payout_method_missing`, `insufficient_available_beans`. |
| GET | /v1/host/withdrawals | Host role. Own withdrawals, keyset paging. Works while payouts are disabled. |
| GET | /v1/admin/ledger/reconciliation | finance/admin. Recomputed live: `customer_diamond_liability` (Σ purchased), `host_bean_liability` (Σ Beans), `discrepancies`; additive `promotional_diamond_liability`, `host_bean_liability_paise`, `unbalanced_entries`, `drifted_accounts[]`. Audited. |
| POST | /v1/admin/ledger/adjustments | finance/admin. `{account: "user:<uuid>:<kind>" or "<uuid>:<kind>", currency, amount (≠ 0), reason}` → `{proposal_id, status: awaiting_second_approval}` (201). Audited. |
| POST | /v1/admin/ledger/adjustments/{proposalId}/approve | **New (additive).** A *different* finance/admin user posts the `adjustment` entry (user bucket vs `sys_<currency>_adjustment`). 409 `second_approver_required`, `adjustment_not_pending`, `adjustment_would_overdraw`. Audited. |
| POST | /v1/admin/ledger/adjustments/{proposalId}/reject | **New (additive).** Different user; marks rejected. Audited. |
| POST | /v1/admin/payout-cycles/{cycleId}/approve | finance. 503 `payouts_not_enabled` while disabled; otherwise `ready` → `approved` (409 `cycle_not_ready`). Audited. |

`CashfreeOrder` = `{order_id: "dsh_<24 hex>", product_id, amount_paise, diamonds, payment_session_id, environment: sandbox|production, state: created|pending|credited|failed|expired, diamonds_credited}`.

## Google Play rules

1. Token hash = sha256(token) hex; ledger key `purchase_credit:<hash>`.
2. `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package}/purchases/products/{productId}/tokens/{token}` with an OAuth token minted from the service account (JWT bearer grant, scope `androidpublisher`).
3. `purchaseState` 0 → credit (Diamonds × quantity) then `POST …:acknowledge` (failures are logged; the app still consumes). 2 → `pending`, no credit (RTDN `ONE_TIME_PRODUCT_PURCHASED` later re-verifies and credits). Anything else → `rejected`.
4. Voided purchases (RTDN `voidedPurchaseNotification` and the daily Voided Purchases API poll): `PurchaseReversal` of `min(purchase Diamonds, purchased balance − max(0, reserved − promotional))`, a negative XP event, purchase state `reversed` with `reversed_diamonds` / `unrecovered_diamonds`. A shortfall is audited as `purchase.reversal_shortfall` for fraud review (no fraud-case table write and no Bean clawback yet: calls do not record which purchase funded them).

## Cashfree rules

- Base URL from `CASHFREE_ENV`: `https://sandbox.cashfree.com/pg` or `https://api.cashfree.com/pg`; headers `x-client-id`, `x-client-secret`, `x-api-version`.
- `order_amount` comes from `economy.diamond_packages.price_paise`; `customer_id` = user id without dashes; `customer_phone` from `auth.users.phone` (via `commerce.customer_phone()`, normalised to 10 digits); `order_meta.return_url` = `CASHFREE_RETURN_URL` (with `order_id={order_id}` appended); expiry 30 minutes.
- Webhook: `x-webhook-signature` = base64(HMAC-SHA256(`x-webhook-timestamp` + raw body, client secret)), constant-time compare, timestamp within 5 minutes; dedupe on sha256(raw body) in `commerce.cashfree_webhooks`. `PAYMENT_SUCCESS_WEBHOOK` → re-fetch `GET /orders/{id}`; the webhook amount is never trusted. `PAYMENT_FAILED_WEBHOOK` / `PAYMENT_USER_DROPPED_WEBHOOK` → `pending` (the session can be retried).
- Credit: ledger key `purchase_credit:cashfree:<order_id>`, `purchase_token_hash = sha256("cashfree:" + order_id)`, rail `cashfree`, all in one transaction that first locks the order row, so webhook and poll racing credit once. A `PAID` order whose amount or currency differs → `failed` (`amount_mismatch`), audited, not credited.

## Jobs (`worker <job>`)

| Job | Schedule | Behaviour |
|---|---|---|
| `reconcile-ledger` | daily 02:30 | Logs liabilities; on any drift or unbalanced entry writes `audit.events` `ledger.drift_detected` and exits non-zero. |
| `expire-promo-diamonds` | daily 01:00 | Promo grants older than 30 days → `PromoExpiry` (oldest-first remainder); a no-op while no `promo_grant` entries exist. |
| `poll-cashfree-orders` | every 10 min | Re-checks `created`/`pending` orders; orders older than 24 h get a final check and are expired. Skips with a log when Cashfree is disabled/unconfigured. |
| `poll-voided-purchases` | daily 04:00 | Voided Purchases API (last 30 days) → same reversal path as RTDN. Skips with a log when Play is not configured. |

## Environment variables

| Variable | Purpose |
|---|---|
| `PLAY_PACKAGE_NAME` | Android application id |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to the service-account JSON (Secret Manager mount). Empty → `play_not_configured` |
| `PLAY_RTDN_AUDIENCE` | OIDC audience set on the Pub/Sub push subscription (use the full webhook URL) |
| `PLAY_RTDN_SERVICE_ACCOUNT` | Service-account email the push subscription signs as |
| `CASHFREE_ENABLED` | `true` to offer the Cashfree rail (default `false` → `rail_disabled`) |
| `CASHFREE_ENV` | `sandbox` or `production` (production required in production) |
| `CASHFREE_CLIENT_ID`, `CASHFREE_CLIENT_SECRET` | Server-held secrets; the secret also verifies webhooks |
| `CASHFREE_API_VERSION` | Default `2025-01-01` |
| `CASHFREE_RETURN_URL` | Optional https/deep link after payment |
| `PAYOUTS_ENABLED` | Keep `false` until incorporation and a payout provider (R3-7) |

## Setup checklists

**Google Play**
1. Play Console → Monetize → In-app products: create the six product ids from `economy.diamond_packages` (`diamonds_4000` … `diamonds_290000`) as consumables with the listed prices.
2. Google Cloud: enable the *Google Play Android Developer API*; create a service account and a JSON key; store it in Secret Manager and mount it at `GOOGLE_APPLICATION_CREDENTIALS`.
3. Play Console → Users and permissions: invite the service account with *View financial data* and *Manage orders and subscriptions*.
4. The app must call `setObfuscatedAccountId(sha256_hex(user_id))` on the billing flow.
5. RTDN: create a Pub/Sub topic, grant `google-play-developer-notifications@system.gserviceaccount.com` *Publisher*, set it in Play Console → Monetization setup. Create a **push** subscription to `https://<api-host>/v1/webhooks/google-play/rtdn` with authentication enabled (service account = `PLAY_RTDN_SERVICE_ACCOUNT`, audience = `PLAY_RTDN_AUDIENCE`).
6. Schedule `poll-voided-purchases` daily. Test with license testers (test purchases have `purchaseType = 0` and are credited).

**Cashfree PG**
1. Merchant account approved for digital goods; generate sandbox, then production, API keys (`CASHFREE_CLIENT_ID` / `CASHFREE_CLIENT_SECRET`).
2. Dashboard → Developers → Webhooks: add `https://<api-host>/v1/webhooks/cashfree` (payment success, failed and user dropped, API version 2025-01-01).
3. Whitelist the app package / return URL domain in Cashfree if required; set `CASHFREE_RETURN_URL`.
4. Set `CASHFREE_ENABLED=true` (server) and `DASHURI_CASHFREE_ENABLED=true` (app). Schedule `poll-cashfree-orders` every 10 minutes.

## Webhook URLs

- Google Play RTDN: `POST https://<api-host>/v1/webhooks/google-play/rtdn`
- Cashfree: `POST https://<api-host>/v1/webhooks/cashfree`

## Payouts

`PayoutProvider` (`internal/modules/payouts/ports.go`) stays provider-neutral; **no adapter exists** because no payout provider has been chosen (R3-7). Withdrawal requests and payout-cycle approval return 503 `payouts_not_enabled` until `PAYOUTS_ENABLED=true`, which must only be set once a provider adapter, the weekly cycle builder and TDS handling exist.

## Schema changes (`20261121000400_money.sql`)

- **Fix to `ledger.apply_posting()`**: the original `INSERT … ON CONFLICT DO UPDATE` failed every debit from a non-negative user bucket (Postgres checks the CHECK constraint on the proposed insert row before resolving the conflict). The function now updates first and inserts only for a new projection row. This affects every module that spends (call settlement, withdrawals, reversals).
- System accounts `sys_diamond_adjustment`, `sys_bean_adjustment`; table `ledger.promo_grant_expiries`; `commerce.purchases.reversed_diamonds / unrecovered_diamonds / reversal_entry_id`; definer function `commerce.customer_phone(uuid)`.
