# Dashuri: from scratch to now

**Written 23 November 2026.** This document tells the whole story in one place: what Dashuri is, how it was planned, how it was built, what is running today, what was decided and why, and what is left. It is a summary. The detailed sources are named at the end.

---

## 1. What Dashuri is

A **paid one-to-one video-call marketplace for India**, Android first.

- **Customers** buy **Diamonds** and spend them per second on video calls with **hosts**.
- **Hosts** set their own per-minute rate (within limits set by their level) and earn **Beans**, which can later be withdrawn as rupees.
- A **Free Call Card** gives eligible new customers one free minute with a random online host; the host is paid ₹10 for it.
- Safety is built in: age gate (18+), reports, blocks, automated nudity checks in the first 3 minutes of a call, human moderation, appeals.

### The money model in one paragraph

Customers pay for Diamonds (Google Play Billing by default). A call is billed **per second, only while both sides are connected**. **16,670 Diamonds spent = 10,000 Beans earned**, and 200 Beans = ₹1. Purchased Diamonds never expire; promotional Diamonds expire after 30 days. Beans are held 7 days before they can be withdrawn; the minimum withdrawal is ₹500. Every movement is a double-entry **ledger** entry, so the books always balance and can be reconciled.

---

## 2. Timeline

| Date | What happened |
|---|---|
| **17 Nov** | Business-model discovery finished (report v0.3). The founder authorised a six-month financial simulation. Database design and migrations written. |
| **21 Nov** | The original project was copied into a clean working copy (`dashuri_mvp`) with a recorded fingerprint of every file. The MVP was built: Go backend, Flutter app foundation, then every feature package. |
| **22 Nov** | MVP finished and documented. Independent security review fixed. Hosted backend set up (Supabase + Google Cloud Run). First APK installed on the founder's phones. Real video calls with Stream, fixed until they worked at 720p. Code pushed to GitHub. |
| **22 Nov (night)** | Live-update bug found and fixed. In-call chat, selfie-only camera, Reels (as a switched-off experiment). |
| **23 Nov** | Whole-app UI/UX and accessibility pass. Session chat for video calls. Dark Mode. Call-screen fixes. Missed-call fix. APK 0.1.4. |

---

## 3. Phase by phase

### Phase 0: Discovery and the business model (to 17 Nov)

Before any code, the business was worked through in writing:

- `docs/business-model-report.md` (v0.3) and `docs/discovery-log.md` record every question, every founder decision, and every risk.
- The **founder's decisions** (S1–S12) set the rules: hosts set their own price (500 to 10,000 Diamonds/min), the Diamond-to-Bean conversion, the Free Call Card, wallet rules, per-second billing, minor protection and the 3-minute nudity check, one shared XP level per account, and Android first on the existing BK Enterprises Play account.
- A **six-month simulation** (`simulation/`, `docs/simulation/`) tested three scenarios. In the base case, operating profit turns positive between months 3 and 6; in the worst case it does not. These are what-if scenarios, not forecasts.
- The research flagged serious risks early: payout providers and Cashfree may refuse the category; Google can remove apps with unmoderated call content; the host share is low (about 13.5% of the customer price).

### Phase 1: Building the MVP (21–22 Nov)

**Decisions on 21 Nov** (`docs/mvp/MVP_DECISIONS_AND_CONTRACT.md`):

- Google Play Billing by default, with Cashfree behind a flag.
- Stream for video.
- A host marketplace, with the Free Call Card as the random-match feature.
- Location is an opt-in coarse city; coordinates are never stored.
- Chat runs on the Go backend plus Supabase Realtime (no second chat provider).
- The UI follows the 19 Nov design handoff and is responsive.

**What was built:**

| Part | Details |
|---|---|
| **Backend** (Go, modular monolith) | Modules: accounts, admin, calls, chat, discovery, economy, freecall, hosts, ledger, levels, location, moderation, notifications, payouts, purchases, safety, textfilter, wallet. Adapters: Cashfree, FCM, Google Play, Play Integrity, Sightengine, Stream, Supabase. About a dozen scheduled background jobs (call clean-up, bean holds, ledger reconciliation, and so on), plus Reels jobs that stay idle while Reels is off. |
| **Database** (Postgres on Supabase) | Row-level security deny-by-default; double-entry ledger with 11 invariants checked on every migration run. |
| **App** (Flutter monorepo) | Feature packages: auth, profile, discovery, free_call, video_call, chat, wallet, purchases, host, safety, notifications, settings, location. Shared packages: core, network, supabase, storage, navigation, design_system. About 58 screens. |
| **Contract** | OpenAPI 3.1 file; architecture docs and decision records. |

**Security review** (independent, no critical findings). Fixed with tests, among others: customers avoiding billing by turning their camera off (billing now follows the host's video); minors buying Diamonds; enforcement not ending live calls; ledger adjustments crediting staff; moderators deciding their own reports; suspended users unable to appeal.

**Tests at the end of the MVP:** 815 Flutter tests, Go unit and race tests, Go integration tests on a real Postgres, and migration checks, all passing.

### Phase 2: Getting it onto the founder's phones (22 Nov)

Everything above had only run in tests. This phase made it real, on the cheapest possible setup (the founder cannot pay running costs, so free tiers only):

1. **Supabase project** ("dashuri", India region): all migrations applied, phone sign-in with test numbers (no SMS bill), demo hosts seeded.
2. **Google Cloud Run** backend: scales to zero when idle, at most one instance, 256 MB, in Mumbai. Secrets in Secret Manager. A budget alert at ₹100.
3. **Stream** for video, with webhooks to Cloud Run.
4. **Android APK** with the Dashuri icon, debug-signed (sideload only).
5. **Real calls.** This took several fixes:
   - Cloud Run rejected call creation until the video resolution was set explicitly.
   - Webhooks were refused until signature checking accepted Stream's compressed bodies.
   - Calls stuck on "Connecting securely…" until two missing video settings were found by turning on verbose SDK logging.
   - Final result: **720p video calls between the founder's two Android phones**, confirmed working.
6. **Pushed to GitHub** on a feature branch (`feat/calls-720p-and-app-icon`). A design archive over GitHub's 100 MB limit was removed from history with the founder's approval.

### Phase 3: Chat and stability (22–23 Nov)

- **Instant updates bug.** Chat, wallet, call and notification updates were waiting up to 20 seconds. Cause: several features subscribed to the same per-user live channel, and the server allows only one subscription per channel on a connection, so each new one silently killed the last. Fixed with one shared channel per topic.
- **In-call chat.** The first version used the same conversation as the Inbox. Later the founder changed the model, and now **each call has its own session chat**: during a call the panel shows only that call's messages; when the call ends, they move into the normal Chat thread, labelled "During video call".
- **See-through chat panel:** no background and no blur, so the other person's face stays visible; every message has its own dark backing so text stays readable over any video.
- **Selfie camera only:** the flip-camera button and its code were removed.

### Phase 4: Reels, an experiment (22–23 Nov)

A short-video feed was built to test a hybrid social plus paid-call product:

- **Founder rule:** hosts upload reels, and only customers scroll them.
- Fully **switched off by default** (a flag on both the backend and the app), with a moderation path (automatic frame checks, then human review).
- **Committed to the repository but not live.** Still missing: the video-playback library (needs approval), Mux for video (paid per minute), and a moderation key. The hosted database has no Reels tables, by choice.

### Phase 5: UI/UX, accessibility and Dark Mode (23 Nov)

Done with Claude CLI and reviewed here:

- A whole-app polish pass: bug fixes (a failed call join no longer sticks on "Connecting securely…"; an approved host enters host mode without a restart; the Chats inbox refreshes), accessibility (readable selected chips, AA-contrast warning and success text), layout hardening for small screens and large text, loading skeletons on every list, and light haptics.
- **Dark Mode** across the app: the app follows the phone's theme, with semantic colours measured to WCAG AA in both themes.
- **1,187 Flutter tests passing across 21 packages** at the time of the UI/UX pass, and more since.

### Phase 6: Call reliability (23 Nov)

- **Incoming-call screen** centred; the **doubled avatar** on the connecting screen removed.
- **Missed calls.** Hosts sometimes did not receive a call although online. Cause: the app heard about a ring only through the live channel, and a closed channel was never reopened. Fixed two ways: the channel reconnects, and an online host's app also checks for ringing calls every 5 seconds. Proven in the simulator with live updates switched off completely.
- **Known remaining gap:** a backgrounded or locked phone cannot ring until push notifications exist.

---

## 4. What is running today

| Piece | State |
|---|---|
| **Phone app** | APK **0.1.4 (build 5)**, debug-signed, app id `com.bkenterprises.dashuri`. Sign-in with test numbers. Calls, wallet, chat, host dashboard, Dark Mode, session chat. **Reels is off.** |
| **Backend** | Cloud Run revision `dashuri-api-00009-cdw` (session chat live). Reels code present but disabled. |
| **Database** | Supabase, all migrations through the chat-context change. **Not** the Reels migration. |
| **Video** | Stream, 720p at 1.5 Mbps, front camera. |
| **Code** | GitHub `ifbkelse-art/dashuri_mvp`, branch `feat/calls-720p-and-app-icon` (`main` is untouched until production). |

**APK history** (each needs a higher build number so the phones accept the update): 0.1.0 (1) → 0.1.1 (2) → 0.1.2 (3, in-call chat on) → 0.1.3 (4, session chat and Dark Mode) → **0.1.4 (5, call fixes)**.

**Costs:** nothing paid is running. Cloud Run scales to zero; Supabase and Stream are on free tiers (the Stream plan has not been confirmed as free); a ₹100 budget alert is set on Google Cloud.

---

## 5. Architecture in short

```text
 Android app (Flutter)  ──HTTPS──>  Go API on Cloud Run  ──>  Postgres (Supabase)
        │                                │   │
        │ live hints (Realtime)          │   └──> Stream (video)  <── webhooks
        └────────── Supabase Realtime <──┘
```

- **The server is the source of truth.** Live messages are only hints; the app re-reads from the API, so a missed hint is recoverable.
- **Billing is server-side**, metered from the video provider's connection events, never from the app.
- **Money is a ledger**: double-entry, balanced by constraint, reconciled daily.
- **Features are isolated packages** with enforced dependency rules, so a feature cannot reach into another.
- **Experiments are flag-gated** and off by default.

---

## 6. Decisions the founder made (the short list)

- Build for **India, Android first**; iOS-ready, not in the launch plan.
- **Hosts set their own price**; minimum 500, maximum 10,000 Diamonds/min, capped by level.
- **Google Play Billing** is the main way to buy Diamonds. Cashfree stays behind a flag.
- **Stream** for video; **Go + Supabase Realtime** for chat.
- Location is an **opt-in coarse city**.
- **Payments are deferred to the end.**
- **Never spend money without asking** (a standing rule: free tiers only).
- **Stay on the feature branch** until production; no push to `main` before that.
- Rebuild the APK after admin, payments and legal work. (Extra builds since then were made at the founder's request, to test fixes.)
- Reels: **hosts upload, customers scroll**.
- In-call chat: **per-call session**, **see-through**, **selfie camera only**.

---

## 7. What is pending

### Waiting on the founder
- **Test APK 0.1.4** on both phones for 24 hours and report bugs.
- **Reels:** keep, change or drop. Keeping it needs approval for a video-playback library, Mux credentials and a moderation key.
- **Admin web app:** the founder asked to change the plan but has not said how. It is needed to approve hosts and handle moderation and payouts without running database commands.
- **Confirm the Stream plan** is the free one.
- **Theme:** the app follows the phone's setting; decide whether to add an in-app switch.

### Needed before a public launch
1. **Payments.** Cashfree's production account was **rejected as a "restricted category"** (reason not detailed). Google Play Billing needs the ~$25 Play developer account and an install from the Play Store (a sideloaded APK cannot buy).
2. **Admin tools** (hosts, moderation, payouts).
3. **Host payouts.** The screens exist, but no money moves, and **no payout provider has accepted the category**. This is a serious dependency in the business model report.
4. **Legal:** terms, privacy policy, grievance officer, host ID and age verification (KYC).
5. **Real SMS sign-in** (today only test numbers work).
6. **Push notifications** (Firebase). Today a backgrounded or locked phone cannot ring.
7. **Safety checks in calls** need a Sightengine key.
8. **Play Store release:** a properly signed build (AAB) and a store listing.

### Small UI items noted but not fixed
1. On the host's "Post a reel" page, "Back to Reels" lands in the customer tab bar.
2. The empty "My reels" page shows two "Post a reel" buttons.
3. The rate card on a host profile is narrower than the other cards.
4. In transaction history, the "Refunds" filter is cut off until swiped.
5. Edit profile drops unsaved changes without asking.
6. The login code screen shows the sign-up "2/6" progress bar.
7. Back from "Become a host" lands on Profile instead of Settings.
8. "Billed 0 s" does not count up during a call (seen only on the local test backend).

### Known risks (from the security review and discovery)
- The Free Call device limit can be dodged by a factory reset.
- Contact details split across several messages get through the text filter.
- Rate limits are per server instance.
- Google may remove an app with unmoderated live video; whether the 3-minute bot plus reports is enough needs a lawyer's opinion.

---

## 8. How to run it

```sh
./scripts/bootstrap.sh        # dependencies and example configs
./scripts/validate.sh         # format, analyze, dependency rules, all tests, Go build, migrations

cd apps/mobile
flutter build apk --release --build-name=<x.y.z> --build-number=<n> \
  --dart-define-from-file=config/phone.json    # phone build (config is git-ignored)
```

- Local configs and secrets live in git-ignored files (`backend/.env`, `apps/mobile/config/*.json`). They are never committed; the repository holds only `*.example.json`.
- Test sign-in numbers and the test code are configured in the Supabase Auth settings; they are not written here on purpose.
- To give a test account free Diamonds, add a balanced `promo_grant` ledger entry in the database.

---

## 9. Source documents

| Topic | File |
|---|---|
| Overview and status | `README.md`, `PROJECT_STATUS.md` |
| Business rules and founder decisions | `docs/business-model-report.md`, `docs/discovery-log.md` |
| MVP decisions and API additions | `docs/mvp/MVP_DECISIONS_AND_CONTRACT.md` |
| Architecture | `docs/architecture/*` |
| Build and deploy | `docs/mvp/BUILD_AND_DEPLOY.md`, `docs/mvp/INTEGRATION_CHECKLIST.md` |
| In-call and session chat | `docs/chat/*` |
| Reels | `docs/reels/*` |
| UI/UX and Dark Mode audits | `docs/uiux/UIUX_AUDIT_AND_IMPLEMENTATION.md`, `docs/uiux/DARK_MODE_AUDIT.md` |
| Financial simulation | `docs/simulation/*`, `simulation/` |
| Git history | `git log` (30 commits, 21–23 Nov 2026) |
