# Integration configuration checklist

Everything below needs an account, credentials or an approval that cannot be created from the code base. The code is implemented against each real API and returns a clear `*_not_configured` (503) error when a value is missing; it never fakes success.

## Supabase (per environment: dev, staging, prod; region Mumbai)
- [ ] Create the project; enable **Phone** auth with an Indian SMS provider (Twilio, MessageBird or Vonage) and OTP rate limits.
- [ ] Switch JWT signing to **asymmetric keys** (JWKS) → `SUPABASE_JWKS_URL`, `SUPABASE_JWT_ISSUER`.
- [ ] `supabase db push` the migrations; set LOGIN passwords for `api_service` / `worker_service` → `DATABASE_URL` (pooler).
- [ ] Server key for Realtime broadcast and Storage signing → `SUPABASE_REALTIME_SERVICE_KEY`, `SUPABASE_STORAGE_SERVICE_KEY` (Secret Manager only).
- [ ] App: `DASHURI_SUPABASE_URL`, `DASHURI_SUPABASE_PUBLISHABLE_KEY` (publishable key only).

## Stream Video (getstream.io), ADR-005
- [ ] Create the app (region close to India) → `STREAM_API_KEY`, `STREAM_API_SECRET`.
- [ ] Webhook URL `https://<api>/v1/webhooks/video/stream`; enable call session participant joined/left, track published and call ended events.
- [ ] Complete the ADR-005 validation checklist (latency in India, pricing, DPDP terms, force-end).

## Google Play
- [ ] Play Console app `com.bkenterprises.dashuri`; target audience 18+; minor-blocking tools; Child Safety Standards; data-safety form (approximate location, camera/mic, phone number, purchase history).
- [ ] In-app products matching `economy.diamond_packages.product_id` (`diamonds_4000` … `diamonds_290000`) as **consumables**.
- [ ] Service account with the Android Publisher API (+ Play Integrity API) → JSON file at `GOOGLE_APPLICATION_CREDENTIALS`; `PLAY_PACKAGE_NAME`.
- [ ] RTDN: Pub/Sub topic + **push** subscription with OIDC to `https://<api>/v1/webhooks/google-play/rtdn` → `PLAY_RTDN_AUDIENCE`, `PLAY_RTDN_SERVICE_ACCOUNT`.
- [ ] Play Integrity: link the Cloud project → `DASHURI_PLAY_CLOUD_PROJECT_NUMBER` (Android build property).
- [ ] License testers for purchase testing on the internal track.

## Cashfree PG (second rail, off by default), ADR-011
- [ ] **Written category approval from Cashfree** (business report R6) and a billing-policy decision for Play builds (User Choice Billing enrollment or non-Play distribution).
- [ ] Sandbox keys → `CASHFREE_ENV=sandbox`, `CASHFREE_CLIENT_ID`, `CASHFREE_CLIENT_SECRET`; webhook `https://<api>/v1/webhooks/cashfree`.
- [ ] Production keys + `CASHFREE_ENABLED=true` (server) and `DASHURI_CASHFREE_ENABLED=true` (app build) only after the two approvals above.
- [ ] Refund and dispute reconciliation procedure (not automated in the MVP).

## Moderation (S7), ADR-013
- [ ] Sightengine account → `SIGHTENGINE_API_USER`, `SIGHTENGINE_API_SECRET`; tune the thresholds with real data.
- [ ] Moderator accounts: `update identity.accounts set roles = roles || '{moderator}' where id = …` (audited procedure).
- [ ] On-call moderation rota for IT Rules takedown timelines; grievance officer named in the legal pages.

## Push notifications
- [ ] Firebase project → `FCM_PROJECT_ID`; add `google-services.json` and `firebase_messaging` to the app (**not yet integrated in the app**; the server FCM sender is ready, and the in-app inbox + Realtime work without it).

## Payouts (disabled; R3-7)
- [ ] Incorporation, payout provider selection and written approval, TDS advice from a CA → then implement a `PayoutProvider` adapter and set `PAYOUTS_ENABLED=true`.

## KYC (manual in the MVP)
- [ ] Choose a KYC vendor (DigiLocker/Aadhaar-offline, PAN, liveness) and implement a `KYCProvider` adapter; until then moderators approve hosts with `POST /v1/admin/hosts/{id}/kyc-decision`.

## Legal (PRO-REVIEW)
- [ ] Terms, privacy notice (DPDP), community rules, host agreement, grievance officer, evidence retention periods. The in-app texts are marked "Draft — pending legal review".
