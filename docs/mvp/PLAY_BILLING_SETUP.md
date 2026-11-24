# Google Play Billing: setup guide and checklist

**Date:** 24 Nov 2026 · **Scope:** setting up Google Play Billing for **testing with license testers** (no real money). The app and server code for Play Billing already exists; this guide covers the console, cloud and build setup around it. Nothing here deploys to production or enables payouts.

**Founder decisions applied:** Play developer account exists; app ID `com.bkenterprises.dashuri` is final; Cashfree stays disabled; 5:4 stays modelling-only (the conversion rule is not touched by this setup).

**Not covered here (still blocks a public launch):** Play policy review for paid 1:1 video, GST/TDS/legal sign-offs, payouts, the ledger fixes (price snapshot, Diamond lots, idempotency fingerprint) which need a separate go-ahead. Register: `docs/finance/dashuri_monetization_open_questions.md`.

**Menu names:** Play Console and Google Cloud rename things often. Where a name below may differ, follow the current Google documentation and compare the purpose, not the label. Items I could not verify are marked *(unverified)*.

## 1. What the code expects (do not change)

| Item | Value | Where |
|---|---|---|
| Package / application ID | `com.bkenterprises.dashuri` | `apps/mobile/android/app/build.gradle.kts` |
| Product IDs (**consumable**, one-time) | `diamonds_4000`, `diamonds_12500`, `diamonds_26000`, `diamonds_54000`, `diamonds_140000`, `diamonds_290000` | `supabase/migrations/20261121000100_mvp_foundation.sql` |
| Prices incl. GST (seed, provisional) | ₹99, ₹299, ₹599, ₹1,199, ₹2,999, ₹5,999 | same |
| Purchase call | `buyConsumable(autoConsume: false)`; `applicationUserName = sha256(user id)` becomes Play's `obfuscatedAccountId` | `play_store_billing.dart` |
| Server verify | `POST /v1/purchases/google-play` (token checked with Google, credited once, then consumed) | `purchases/service.go` |
| Refund notifications | `POST /v1/webhooks/google-play/rtdn` (Pub/Sub push with OIDC) | `purchases/http.go`, `googleplay/push.go` |
| Server settings | `PLAY_PACKAGE_NAME`, `GOOGLE_APPLICATION_CREDENTIALS`, `PLAY_RTDN_AUDIENCE`, `PLAY_RTDN_SERVICE_ACCOUNT` | `backend/.env.example` |
| Daily backup job | `poll-voided-purchases` (needs a scheduler; optional for first tests) | `docs/mvp/BUILD_AND_DEPLOY.md` |

## 2. Play Console

- [ ] **Create the app** `com.bkenterprises.dashuri` (name Dashuri). The package name cannot change afterwards.
- [ ] **App content:** target audience 18+, the minors-blocking tools, Child Safety Standards self-certification, data-safety form (approximate location, camera, microphone, phone number, purchase history), content rating, and a privacy policy URL. Play requires UGC apps to have reporting and blocking; these exist in the app.
- [ ] **Payments profile and merchant account:** needed to sell. Use the business details your CA confirms (GST registration status matters here).
- [ ] **Service-fee tier:** enrol in the 15% tier if the console offers it (account group). Screenshot the status for the finance register (item C-02).
- [ ] **In-app products:** create the six products above as **consumable** one-time products with the exact IDs, set to Active, INR prices as listed. *(The console may call this "One-time products"; follow its flow for consumables.)* Don't change a product ID after creating it.
- [ ] **License testers:** add the Google accounts that will test (Setup → License testing, *name unverified*). Their purchases use test payment methods and cost nothing.
- [ ] **Internal testing track:** create it, add the testers' emails, and publish the first release (section 4). Only a build installed **from Play** can query products and purchase.
- [ ] **Play App Signing:** accept the default. Keep the upload key safe (section 4).

## 3. Google Cloud (project `dashuri-dev`; every item that creates a resource needs your OK)

- [ ] **Enable** the *Google Play Android Developer API* (free).
- [ ] **Service account** (e.g. `dashuri-play-verifier`): create it with no project roles, then create a JSON key. **Treat the key as a password.** Never commit it. Store it in Secret Manager (you have 3 of 6 free secret versions in use).
- [ ] **Link it in Play Console:** invite the service account's email under Users and permissions and give it permission to view financial data and manage orders *(exact permission names unverified)*. Allow some hours for it to take effect.
- [ ] **Cloud Run mount:** mount the secret as a file (for example `/secrets/play-sa.json`) and set `GOOGLE_APPLICATION_CREDENTIALS` to that path. Today the deployed `dashuri-api` has only `PLAY_PACKAGE_NAME`, so these values are not set yet. *This is a deployment change and needs your approval.*
- [ ] **RTDN:** in Play Console (Monetization setup → real-time notifications, *name unverified*), enter a Pub/Sub topic. Create the topic, grant Google Play's publisher service account the Pub/Sub Publisher role on it (per Google's RTDN documentation), then create a **push subscription** to `https://<api-url>/v1/webhooks/google-play/rtdn` with OIDC. Set `PLAY_RTDN_AUDIENCE` (the audience you gave the subscription) and `PLAY_RTDN_SERVICE_ACCOUNT` (the push service account's email) on the server. Pub/Sub's free tier covers this volume.
- [ ] **Optional:** a daily `poll-voided-purchases` run as a backup. That needs Cloud Scheduler, which isn't enabled in `dashuri-dev`; its free allowance is unverified, so ask before enabling.

## 4. Build and upload

- [ ] **Upload keystore:** create it locally, back it up, and add the signing config. Release builds currently sign with the debug key, which Play will refuse. Never commit the keystore or its passwords.
- [ ] **App bundle:** `flutter build appbundle --release -t lib/main_production.dart --dart-define-from-file=config/production.json` as in `docs/mvp/BUILD_AND_DEPLOY.md`. Check the config points to the right API URL and **leaves Cashfree off**.
- [ ] **Play Integrity:** link the Cloud project and set `DASHURI_PLAY_CLOUD_PROJECT_NUMBER` before the upload, per the build guide.
- [ ] **Upload** to the internal testing track. Version code must increase on every upload.
- [ ] **Install from the internal-testing link on the tester's phone.** A sideloaded debug APK will not find the products.

## 5. Test plan (tester accounts only)

| # | Test | Expected |
|---|---|---|
| 1 | Open the wallet | Six packs show with Play's prices |
| 2 | Buy Starter | Server credits 4,000 Diamonds once; the purchase is consumed; the wallet updates |
| 3 | Buy the same pack again | A second purchase works (consumable) |
| 4 | Kill the app mid-purchase, reopen | The pending purchase completes once; no double credit |
| 5 | Replay the same token (retry) | Same result, no extra Diamonds |
| 6 | Slow or declined test card | No Diamonds until Play confirms |
| 7 | Refund a test purchase in Play Console | Within minutes (RTDN), unspent Diamonds are reversed; spent ones are recorded as a shortfall |
| 8 | Two accounts, one token | Refused ("belongs to another account") |
| 9 | Server down during purchase | The app retries the verify call; Play shows it unacknowledged until the server confirms |

## 6. After testing, before real money (not part of this setup)

- Play policy review, GST/TDS/legal sign-offs, payouts, ledger fixes, and the host-clawback gap on refunds (found in the audit).
- Rotate the service-account key before production and keep it in Secret Manager only.
- Production Cloud Run, Supabase Pro and the scheduler (all paid items) are separate approvals.
