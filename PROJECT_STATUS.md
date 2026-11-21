# Dashuri MVP — project status (2026-11-22, in progress)

Working copy: `~/Development/projects/dashuri_mvp`, with local git history of every step. The original `~/Development/projects/Dashuri` was not modified. A SHA-256 snapshot of its 1,070 files was taken before copying; re-verify it as described in "Remaining work" below.

Founder decisions and contract: `docs/mvp/MVP_DECISIONS_AND_CONTRACT.md`. Payments use Play Billing by default with Cashfree behind a flag. Video uses Stream. The model is the host marketplace. Location is a coarse, opt-in city. Chat uses Go and Supabase.

## Completed
| Area | State |
|---|---|
| Backend (Go) | Every endpoint implemented, with no 501s left: accounts, location, discovery, chat, safety, notifications (FCM), calls (Stream adapter, metering, settlement, reservations), moderation (Sightengine, first 3 minutes), free call (Play Integrity), hosts (manual KYC), wallet, purchases (Play verify/consume/RTDN plus Cashfree orders/webhook/poll), payouts (disabled per R3-7), admin (reconciliation, dual-control adjustments). 11 worker jobs. |
| Database | 4 new migrations on top of the 6 originals; RLS forced and client roles revoked on every new table. |
| Flutter features | Wallet, purchases (Play + Cashfree), chat (two-pane on tablets), host app (H01–H25), discovery, free call, video call (Stream, moderation frames, incoming calls). All screens are responsive at phone, foldable and tablet widths. |
| Design system | Tokens from the handoff, M3 theme, `AdaptiveShell` (bar on phones, rail on tablets), shared components. |
| Android | Debug APK built with all SDKs (the last full build was before feature integration). Permissions, R8, backup off, Play Integrity channel. |
| Docs | ADR-011 (Cashfree), ADR-012 (city), ADR-013 (moderation frames), `docs/mvp/BUILD_AND_DEPLOY.md`, `docs/mvp/INTEGRATION_CHECKLIST.md`, `docs/mvp/api/*.md`, OpenAPI with the MVP paths. |

## Tests executed (actual results)
- Backend: `go test ./...` passed for all packages. The full integration suite (`scripts/test-backend-integration.sh`, real Postgres as `api_service`) passed for every package **before** the last two security fixes. It has not been re-run since; see Remaining work.
- Migrations: `validate-migrations.sh` passed all invariants.
- Flutter, as reported by each workstream: wallet 25, purchases 50, chat 33, host 205, discovery 62, free_call 26, video_call 121, design_system 5. All passed, with analyze clean and dependency rules OK.

## Partially complete
- **FE-core** (app shell and router with onboarding guard, auth/OTP, profile, safety, settings, location, notifications inbox): an agent was still working on it when the usage limit was reached. It has not been integrated or verified.
- **Photo moderation follow-up** (approve/reject endpoints, delete photo, photo URLs on host detail and call peers): an agent was still working on it.
- **Integration still to do:**
  - wrap the app in `IncomingCallWatcher`;
  - add `cashfreeEnabled` to `AppConfig`;
  - add a photo picker (`image_picker`);
  - add an `X-Client-Platform` header to `ApiClient`.

## Security review: done but not yet fixed
Fixed: billing now counts the host's video only, so a customer can't pause it by turning off their camera; minors and restricted accounts can't buy Diamonds; the free-call compensation rule; server-side Play consume; and the ledger trigger bug that rejected valid debits.

Still open:

| # | Severity | Issue |
|---|---|---|
| 3 | Medium | Enforcement must end live calls. |
| 4 | Medium | Free Call device binding is client-derived (it relies on Play Integrity app recognition). Add a server nonce. |
| 5 | Medium | Ledger adjustments must not credit the proposer's or approver's own account. |
| 6 | Low | Moderators must not decide their own reports or act against staff. |
| 7 | Low | Suspended and banned users can't reach appeals. |
| 8 | Low | No per-call rate limit on moderation frames. |
| 9 | Low | Stream webhook dedupe should use a body hash. |
| 10 | Low | The Play obfuscated account id should be required. |
| 11 | Low | `DASHURI_ENV` should default to production. |
| 12 | Low | Log `r.Pattern`, not the path. |

Hardening items are listed in the review notes (contact filter across messages, phone-only auth in production).

## External credentials required
See `docs/mvp/INTEGRATION_CHECKLIST.md`: Supabase (phone auth, JWKS, service keys), Stream, Google Play (products, service account, RTDN, Integrity), Cashfree (plus written category approval), Sightengine, FCM, payout provider, KYC vendor, and legal review.

## Remaining production-readiness work
1. Finish and integrate FE-core and the photo moderation follow-up.
2. Re-run `scripts/validate.sh`, the integration suite (purchases tests may need age-eligible principals after the new check), and `flutter build apk`.
3. Fix the open security items above.
4. Verify the original folder is unchanged. The snapshot was written to this session's scratchpad (`original_snapshot.sha256`), which is temporary and may be gone. If it is, `diff -rq` the two folders instead, excluding `build`, `.dart_tool`, `.gradle`, `Pods`, `ephemeral` and `node_modules`. In `dashuri_mvp`, also exclude `.git` and the new MVP files.
5. Release signing, real credentials, legal review, Play Console policy setup, FCM in the app, and a payout provider.
