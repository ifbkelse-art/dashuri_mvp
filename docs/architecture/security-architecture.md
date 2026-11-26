# Security architecture

The architecture supports these controls; it does **not** by itself make Dashuri legally compliant. Items marked PRO-REVIEW need a lawyer or CA (see the business-model report, B4).

## Authentication

- **Users:** Supabase Auth phone OTP. The app holds only the publishable key.
- **API:** verifies the access token (JWT) signature against the Supabase project JWKS, plus `iss`, `aud=authenticated`, `exp`/`nbf`. Implementation is a TODO in `auth.JWKSVerifier`; until it exists every user request returns 401.
- **Roles and status** (`customer`, `host`, `moderator`, `admin`, `finance`; suspended or banned) come from `identity.accounts` on every request, never from token claims.
- **Webhooks:** the video provider uses an HMAC signature over the raw body; Google Pub/Sub push uses an OIDC token with an audience check. Webhook events are deduplicated.
- **Staff:** the same auth plus roles. Finance adjustments need two different people; appeals need a different reviewer than the original decision.

## Authorisation

- Every service method receives `auth.Principal` and checks ownership (a participant of the call, the owner of the withdrawal, …).
- Role gates use `auth.Require`.
- The database is a second line: client roles have no grants or policies on domain schemas; service roles cannot update or delete ledger history.
- **Verified Host and pricing:**
  - Only moderators and admins change a verification status, and never on their own account (service check plus DB CHECKs).
  - Price eligibility (level, verification) is read server-side under the host row lock; client-sent level or verification fields are rejected as unknown fields.

## Secrets

| Secret | Lives in | Never in |
|---|---|---|
| Database password (`api_service`, `worker_service`) | Secret Manager → Cloud Run env | App, repo |
| Supabase service-role key | Secret Manager (ops only; not used by the API) | App, API config |
| Realtime publish key | Secret Manager | App |
| Google Play service account | Secret Manager (mounted file) | App, repo |
| Stream API secret | Secret Manager | App (the app receives short-lived call tokens only) |
| Payout provider and KYC keys | Secret Manager | App |

`.gitignore` excludes `.env`, app config JSON, keystores and service-account files. Only `*.example*` files are committed.

## Input validation and abuse controls

- JSON bodies are capped at 64 KB, unknown fields are rejected, and `validate()` runs on every request type (required fields, enums, UUIDs, lengths, rate 500–10,000).
- Rate limiting: per-user token bucket per route (per instance today). Shared limits and Cloud Armor are needed before scale (ADR-007).
- Idempotency: required on every value-moving or create POST. Same key with a different body → 422; a key still in progress → 409.
- Chat and profile text are screened server-side for contact details (phone, UPI, links) to stop off-platform payment, which is a revenue and safety risk.
- Free Call Card: Play Integrity device binding plus phone hash, enforced by UNIQUE constraints.

## Financial integrity

See `financial-ledger-design.md`:
- immutable double-entry ledger;
- database-enforced balance and non-negativity;
- exactly-once keys;
- reservations against concurrent spending;
- server-only metering;
- daily reconciliation;
- dual-control adjustments;
- fraud holds via the 7-day Bean hold and clawback.

## Safety and moderation

| Control | Where | Status |
|---|---|---|
| Minor protection | Play Console minor-blocking for random chat (Free Call Card); app age gate (`/v1/me/age/declaration`); host KYC with verified DOB; route guard blocks ineligible users | Mandatory (S7). The gate is self-declared for customers; stronger age assurance is PRO-REVIEW. |
| Nudity detection | `moderation` module: frames from the first 3 minutes → `NudityClassifier` → end call and open a case | Founder model (S7); vendor, frame source and thresholds unresolved |
| After 3 minutes | Report button (ends the call client-side) → `POST /v1/reports` → priority queue (nudity and minor safety first) | Founder model |
| Blocking | `safety.blocks`; enforced in discovery, calls, chat, profiles | |
| Review and enforcement | `/v1/admin/moderation/*`; `safety.enforcement_actions`; audit log | |
| Evidence | Private bucket, references in `moderation.evidence`, retention from legal advice, access audited | PRO-REVIEW |
| Verified Host evidence | Face video + ID images in the private `host-verification-evidence` bucket. Signed upload. Staff read through a 5-minute signed URL, audited before issue. Never in public APIs. Purged 90 days after a final decision. No biometric templates (ADR-014) | PRO-REVIEW (retention, consent text) |
| Appeals | `/v1/appeals`, decided by a different reviewer | |
| Takedown timelines | IT Rules 2026 amendment (reported: 2 h for intimate imagery on complaint) → on-call moderation | PRO-REVIEW |
| Child sexual abuse material | Mandatory reporting path, separate from ordinary moderation; Play Child Safety Standards | PRO-REVIEW |

**Open question (to validate with the video provider):** frames are captured either server-side (preferred; the client cannot skip it) or by the client with server checks that frames arrived. The architecture supports both through `FrameSource`.

## Privacy (DPDP)

- **Minimisation:**
  - The phone number stays in Supabase Auth; the database stores only a hash for the Free Call Card.
  - KYC documents stay with the vendor.
  - Play purchase tokens are stored only as hashes.
  - Verified Host evidence is stored as a private object with metadata only, deleted on schedule, and never processed into a face template.
- **Consent** (`identity.consents`) gates analytics and marketing.
- **Rights:** deletion (anonymise where law or tax requires retention), data export.
- **Logs** exclude personal data (list in `platform/logging`).
- **Retention** periods per table are PRO-REVIEW and are enforced by the `retention-enforcement` job.

## Transport and platform

- HTTPS only (Cloud Run). HSTS at the load balancer.
- Containers are distroless and run as non-root.
- Android: release builds need R8/minification, no cleartext traffic, and a Play App Signing key. These are not configured yet.
