# Dashuri: overall development to date

**Written 27 November 2026.** Branch `feat/calls-720p-and-app-icon` (HEAD `b71be2a`), pushed to `github.com/ifbkelse-art/dashuri_mvp`. `main` is untouched until production.

Sources: git history, `PROJECT_STATUS.md`, `docs/DASHURI_JOURNEY.md`, `docs/HANDOVER.md`, and the project memory notes. Where those disagree with the code, trust the code.

---

## 1. What Dashuri is

A **paid one-to-one video-call marketplace for India**, Android first.

- **Customers** buy **Diamonds** and spend them per second on video calls with **hosts**.
- **Hosts** set their own per-minute rate (capped by level) and earn **Beans**, withdrawable as rupees later.
- A **Free Call Card** gives eligible new customers one free minute with a random online host (host paid ₹10).
- **Safety:** 18+ age gate, reports, blocks, automated nudity checks in the first 3 minutes, human moderation, appeals.
- **Money:** every movement is a double-entry ledger entry; billing is per second, only while both sides are connected. Current rule in code: 16,670 Diamonds spent = 10,000 Beans, 200 Beans = ₹1.

## 2. Timeline

| Date | Milestone |
|---|---|
| 17 Nov | Business-model discovery finished (report v0.3); six-month simulation authorised; DB design written. |
| 21 Nov | Clean working copy `dashuri_mvp` created (original verified unchanged by SHA-256). Go backend and Flutter foundation built, then every feature module. |
| 22 Nov | MVP complete and documented; security review findings fixed. Hosted backend (Supabase + Cloud Run) up; first APK on founder's phones. Stream video fixed at 720p. Launcher icon. Shared realtime channels. In-call chat (flagged), Reels experiment. |
| 23 Nov | Whole-app UI/UX and accessibility pass (`dda1269`). Session chat for calls, Dark Mode contrast, Reels UI (`441e81c`). Call-screen and missed-call fixes. Verified Host + level pricing built. |
| 24 Nov | Google Play Billing integrated and tested end to end on the internal track. Play refund handling fixed. Admin web console built. 5:4 monetization modelled; decision pack written. |
| 25 Nov | Public marketing website and v1.0 policies for Netlify (`dashuri.netlify.app`) with security headers. |
| 26–27 Nov | Host Home online session, virtual gifts, host waiting room, arrival selfie, R2 Reels pipeline, admin pages, host Reels tab (`b71be2a`). |

## 3. Architecture

| Layer | Tech |
|---|---|
| Backend | Go modular monolith, Postgres, ledger-first (balances never updated directly), 13+ scheduled worker jobs |
| Auth / realtime | Supabase phone OTP, JWT/JWKS verification, Realtime (one shared channel per topic) |
| Video | Stream (720p, front camera), server-side metering, webhooks |
| Mobile app | Flutter, feature packages with layer and dependency rules (Melos workspace, 21 packages) |
| Admin console | `apps/admin`: React 18 + Vite + TypeScript, role-gated (admin / moderator / finance) |
| Website | `apps/website`: static marketing + policy pages, Netlify |
| Hosting | GCP project `dashuri-dev` (Cloud Run `dashuri-api`, asia-south1), Supabase `aesecwotyjtmmrexogiy` (ap-south-1) |
| Payments | Google Play Billing (default, live on internal track); Cashfree behind a flag (production rejected as restricted category) |

Key decisions are recorded as ADRs (011–015) and in `docs/mvp/MVP_DECISIONS_AND_CONTRACT.md`.

## 4. What is built

### Customer app
Phone OTP and onboarding (A01–A15), profile, discovery (filters, paging, online count), Free Call Card matchmaking, video call (V01–V18, moderation frames, incoming-call watcher with realtime reopen), chat (CH01–CH05, privacy, contact-detail filter, two-pane on tablets), wallet and purchases (W01–W09), location (opt-in coarse city; coordinates never stored), safety (report/block/appeals), settings (consents, deletion with 7-day grace, data export).

### Host app
Application and manual KYC, availability and heartbeat, price selector, earnings, withdrawals (503 while payouts are off), dashboard, Verified Host application (face video + ID), Reels tab, online session, waiting room, arrival selfie.

### Backend modules
Identity, profile/photos (moderation, signed URLs), discovery, matchmaking (Play Integrity, one card per phone and device, 20/day host cap), calls, chat, wallet/ledger, purchases/payouts, moderation/safety, hosts, admin/finance, gifts, reels.

### Added since the MVP

| Feature | State |
|---|---|
| **Verified Host + level pricing** (23 Nov): staff review, private evidence bucket, price caps (`min(3,000, level × 1,000)`), `is_verified` now means Verified Host | Committed in `b71be2a`; hosted migration status: confirm before relying on it |
| **Admin console** (24 Nov): host activation, verification review, photos, reports/appeals, finance reconciliation, dual-control adjustments, audit | Built; Firebase Hosting + `ADMIN_ORIGINS` deploy pending approval |
| **Google Play Billing** (24 Nov): 6 consumable products, server verify and consume, RTDN refunds via Pub/Sub, voided-purchase poll | Working on internal track, dev backend |
| **In-call / session chat** | Per-call session chat joins normal Chat at call end; flag-gated |
| **Reels** | Flags off. R2 + own ffmpeg pipeline replaces Mux (SigV4 adapter, `reels-process-media` job); no Cloudflare credentials yet |
| **Virtual gifts** (26 Nov) | Behind flags `GIFTS_ENABLED` / `DASHURI_GIFTS_ENABLED`, default off; uses the current conversion rule |
| **Host waiting room, online sessions, arrival selfie** | Flagged; staff review for arrival photos; purge job |
| **Dark Mode** | Tone-based colours plus a contrast auditor; app follows system theme |
| **Public website + policies** | Ready for Netlify |

## 5. Monetization work (modelling only)

- 24 Nov: **5 Diamonds → 4 Beans at ₹0.005/Bean** approved for the financial model only, not for deployment (about +33% host pay versus the current rule).
- Written: monetization math v3, open-questions register, reference ledger with 22 tests, ledger engineering spec, audit report, readiness checklist. Verdict: **not implementation-ready**.
- Known code gaps: `ledger.BeanClawback` has no caller (no host clawback on chargeback); `PostEntry` replays a reused key without a payload check; purchases store no price; reversals are pooled.
- Biggest listing risk: Google Play's "compensated arrangements" policy.

## 6. Quality

Last full validated run (23 Nov): `scripts/validate.sh` passes with 1,259 Flutter tests across 21 packages; Go `-race` and the real-Postgres integration suite pass in 31 packages; 17 migration invariants pass. Later work added admin-console tests (28), Go unit tests (10 new) and one Postgres integration test. **A fresh full run has not been recorded since the 26–27 Nov work.**

## 7. Founder rules in force

- **Cost:** cheapest or free tier only; ask before creating any paid resource.
- **Branching:** stay on the feature branch; no `main` until production.
- **Rebuild the APK** after admin, payments or legal changes; verify at 720p.
- **Financial rules** (conversion, commission) do not change without approval.
- **Deploys and hosted migrations** need explicit approval.

## 8. Open items

1. Full re-validation (Flutter, Go, integration, migrations) after the 26–27 Nov changes.
2. Hosted Supabase migrations for Verified Host, gifts, online sessions, arrival photos, R2 reels: apply only with approval.
3. Cloud Run redeploy from a clean commit. Earlier revisions 00012/00013 were built from a dirty tree and broke the refund path; the deploy must come from HEAD.
4. Admin console deploy (Firebase Hosting + `ADMIN_ORIGINS`), separate admin test number.
5. Cloudflare R2 credentials and the media Dockerfile build, then retire Mux.
6. Unanswered founder items (27 Nov directive): host mini-games removal, ad scope (CAS.AI), gift names/prices and animation redesign.
7. 5:4 monetization: resolve open questions and the readiness checklist before any activation.
8. Payments to production: Play Billing refund-notification edge cases; Cashfree rejected; payouts off.
9. Release: Play Store listing, production signing, policy review (compensated-arrangements risk).
10. Teardown of dev cloud resources when exploration ends.

## 9. Where to look

| Need | File |
|---|---|
| Module status | `PROJECT_STATUS.md` |
| Story from scratch | `docs/DASHURI_JOURNEY.md` |
| Account handover log | `docs/HANDOVER.md` |
| Verified Host spec | `docs/mvp/VERIFIED_HOST_AND_PRICING.md` |
| Gifts, host waiting/arrival | `docs/gifts/VIRTUAL_GIFTS.md`, `docs/host/HOST_WAITING_AND_ARRIVAL_PHOTO.md` |
| Reels on R2 | `docs/reels/DASHURI_REELS_R2_MIGRATION.md` |
| Money model and audit | `docs/dashuri_monetization_math.md`, `docs/finance/` |
| Play Billing setup | `docs/play-store/` |
| Admin console | `apps/admin/README.md` |
