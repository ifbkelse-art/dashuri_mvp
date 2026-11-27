# Phase 13: physical-device QA

**Prepared 27 Nov 2026** for the second closed-testing update. Code under test: branch `feat/calls-720p-and-app-icon` at or after `54ff1e4` (version **0.1.0+4**, versionCode 4).

Fill in **Actual**, **P/F** and **Notes** while testing. Use **P** (pass), **F** (fail), **B** (blocked: say why) or **N/A**.

## 0. Setup (do once)

**Devices:** two Android phones. Phone A is the **customer**; phone B is the **host** (an approved host account). Ideally one is a small or low-end phone, such as 5.5–6" with 3–4 GB RAM. Record each phone's model, Android version and RAM:

| | Model | Android | RAM | Screen |
|---|---|---|---|---|
| A (customer) | | | | |
| B (host) | | | | |

**adb** is installed at `~/Library/Android/sdk/platform-tools/adb`. Add it to the shell once:

```sh
echo 'export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"' >> ~/.zshrc && source ~/.zshrc
adb version
```

On each phone:
1. Settings → About phone → tap **Build number** 7 times.
2. Developer options → **USB debugging** on.
3. Connect by USB and accept the "Allow USB debugging" prompt.
4. Run `adb devices`; the phone must be listed as `device`.

**Build to install:**
- **Recommended:** upload the AAB to the Play **internal testing** track and install from Play. Play Billing only works for a Play-installed build from a licence-tester account.
- For non-payment checks you can sideload a debug APK instead:

  ```sh
  cd apps/mobile
  flutter build apk --debug --dart-define-from-file=config/phone.json
  adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk
  ```

**Backend:** the build talks to the hosted **dev** backend (`config/phone.json`). That backend runs an older revision. Tests marked **[needs backend update]** only pass after the founder-approved backend redeploy and hosted migrations (Phase 14 checklist §3).

**Logs while testing (optional):** `adb -s <serial> logcat -s flutter`

## 1. Authentication

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| AUTH-01 | Fresh install, new number | Open app → Create account → enter number → Send code | OTP SMS arrives; the code screen shows the number and a resend countdown | | | |
| AUTH-02 | AUTH-01 | Enter a wrong code | "That code didn't match or has expired"; can retry | | | |
| AUTH-03 | AUTH-01 | Enter the right code | Goes to birthday (age gate) | | | |
| AUTH-04 | At the age gate | Enter a date under 18 | Refused; cannot continue to the app | | | |
| AUTH-05 | At the age gate | Enter an 18+ date and tick confirm | Profile step, then experience, rules, permissions | | | |
| AUTH-06 | Signed in | Force-stop the app (Settings → Apps → Force stop) and reopen | Lands in the app, still signed in (no login) | | | |
| AUTH-07 | Signed in, app idle | Leave the app in the background more than 1 hour, then turn on **airplane mode** and open it | No endless spinner: screens show an offline error with Try again; after reconnecting, Try again works | | | Regression for the token-refresh fix (`8965dad`) |
| AUTH-08 | Signed in | Profile → Settings → Log out | Back at Welcome; reopening the app stays signed out | | | |
| AUTH-09 | Existing account | "I already have an account" → number → code | Signs in to the same account (balance and history intact) | | | |
| AUTH-10 | Too many attempts | Request codes repeatedly | "Too many attempts. Please wait…" shown; no crash | | | |

## 2. Customer: discovery and profiles

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| DISC-01 | Host B online | A opens Discover | B appears with "Online", rate "N / min", languages | | | |
| DISC-02 | — | Tap language chips, open Filters, change sort | The list updates; "Recommended" sort menu opens | | | |
| DISC-03 | No host online | Open Discover | "It's quiet right now" with Refresh | | | |
| DISC-04 | Airplane mode | Pull to refresh | "Couldn't load hosts" with Try again; works after reconnect | | | |
| DISC-05 | B online | Open B's profile | Name with one verified badge (if verified), status, level, About, "Video call · N / min" | | | |
| DISC-06 | B busy (in a call) | Open B's profile | Button disabled: "In a call. Try again soon" | | | |
| DISC-07 | — | Profile ⋮ → Report / Block | Report form opens; Block asks to confirm | | | |
| DISC-08 | Balance pill | Tap the Diamond pill at the top of Discover | Opens Buy Diamonds | | | |
| DISC-09 | After buying Diamonds | Return to Discover (don't pull to refresh) | The pill shows the new balance within a few seconds | | | [needs backend update] for call/gift refreshes |

## 3. Wallet and Google Play purchases (Play-installed build, licence tester)

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| PAY-01 | Licence-tester account on A | Wallet → Buy Diamonds | Packs with Play prices; "≈ N min with …" when opened from a host | | | |
| PAY-02 | PAY-01 | Pick a pack → Continue → pay with a test card | "Payment successful", +N Diamonds; the wallet balance increases by exactly N | | | |
| PAY-03 | PAY-02 | Wallet → History | One "Diamonds purchased" line with the right amount (no duplicate) | | | |
| PAY-04 | — | Buy the **same pack again** right away | The purchase works (the previous one was consumed) | | | |
| PAY-05 | — | Start a purchase; in the Play sheet use the test card "Slow test card, approves after a few minutes" | Shows "Confirming your payment"; Diamonds arrive once approved | | | |
| PAY-06 | — | Use "declines" test card | "Payment didn't go through"; no Diamonds; Try again works | | | |
| PAY-07 | — | Pay, and **force-stop the app immediately** while it says verifying | On reopen (or the next app start/resume) the Diamonds arrive once, without opening Buy Diamonds | | | Purchase recovery (e280429) |
| PAY-08 | — | Cancel the Play sheet | Back on packages; nothing charged | | | |
| PAY-09 | A purchase older than a few minutes | Refund it in Play Console (Order management → Refund) | Within minutes (RTDN) or the next daily poll, the unspent Diamonds are removed; History shows "Purchase refunded" | | | Needs RTDN configured |
| PAY-10 | Under-18 or restricted account | Try to buy | Refused with a clear message | | | |

## 4. Calls (A = customer, B = host)

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| CALL-01 | B online with the app in the foreground; A has enough Diamonds | A: profile → Video call → Start | A sees "Ringing…"; B's phone shows the incoming call screen at once (from any tab) | | | |
| CALL-02 | CALL-01 | B accepts | Both see each other at 720p; timer starts; "rate · used" pill on A | | | |
| CALL-03 | In a call | Toggle the mic on each side | The other side stops/resumes hearing | | | |
| CALL-04 | In a call | Talk 65 s, then A ends | Summary on A: 1 min 05 s, Diamonds used = 65/60 × rate (rounded as shown); B's summary shows Beans earned | | | Billing per second, server-side |
| CALL-05 | CALL-04 | Check A's wallet and B's earnings | A's balance dropped by exactly the summary amount; B's "on hold" Beans rose | | | |
| CALL-06 | Ringing | B declines | A: "couldn't take your call · You haven't been charged"; B: Host Home "Call declined. You're still online." (not stuck on "Incoming call") | | | Regression 6d2596e |
| CALL-07 | Ringing | Nobody answers about 30 s | Missed for both; nothing charged; B's Host Home says "You missed a call" | | | |
| CALL-08 | In a call | Turn Wi-Fi/data off on A for 10 s, then on | "Connection lost · Billing is paused"; the call resumes; no charge for the gap | | | |
| CALL-09 | In a call | A presses Home (app to background) | Note what happens (calls are not kept alive in the background in this build). Expected: no crash; if the call ends, billing stops | | | Known limit |
| CALL-10 | Low balance | Start a call with about 1–2 minutes of balance | "30 seconds of talk time left" banner; the call ends automatically at 0; no negative balance | | | |
| CALL-11 | In a call | Tap Report (first control, flag) | Asks to confirm; the call ends and the report form opens | | | |
| CALL-12 | In a call | Check controls | Report is far left, End call far right with a gap; nothing overlaps on a small phone | | | |
| CALL-13 | B's app closed | A tries to call B | B shows offline in Discover (about 90 s after closing); A cannot start a call | | | No push: hosts must keep the app open |
| CALL-14 | First call ever on a phone | Accept camera/mic permission prompts | Video works after granting; denying shows a clear message | | | |

## 5. Host flows (phone B)

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| HOST-01 | Approved host, offline | Host Home → Go online | (If arrival photos are on: optional photo prompt.) Card turns green "You're online · Online for N min" | | | |
| HOST-02 | Online | Keep the app open 5 min | Stays online (heartbeat); still listed in A's Discover | | | |
| HOST-03 | Online | Go offline | "Session ended" with duration; disappears from Discover | | | |
| HOST-04 | Online | Toggle "Free Call Card calls" | The switch changes; no duplicate on/off chip | | | |
| HOST-05 | After calls | Earnings tab | Beans balance; **"Available"** (not "Withdrawable"); no Withdraw button; note "Withdrawals aren't open yet…" | | | Payouts off |
| HOST-06 | HOST-05 | Tap the note | Withdraw screen opens directly on "Withdrawals are coming soon" | | | |
| HOST-07 | — | Rate → change the rate within the limit → Save | The new rate shows on Host Home and in A's Discover | | | |
| HOST-08 | — | Rate above the level limit | Blocked with an explanation (Verified Host CTA above 3,000) | | | |
| HOST-09 | Non-verified host | Open the Verified Host page | Loads or explains; no crash | | | [needs backend update] older backend may show an error |
| HOST-10 | Arrival photos enabled build | Go online → Capture photo | **In-app** front camera (not the system camera app), shutter, then preview with Retake / Use photo | | | 3513d2a |
| HOST-11 | HOST-10 | Deny camera permission | "Camera access needed" with Try again and Not now; going online still works without a photo | | | |
| HOST-12 | HOST-10 | While the camera is open, press Home, then return | The camera reopens (no black screen) | | | |
| HOST-13 | — | Host Calls tab | Recent calls listed | | | |

## 6. Gifts (only if `DASHURI_GIFTS_ENABLED` and backend `GIFTS_ENABLED`; off by default)

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| GIFT-01 | In a call, A has a balance | A: Gift → choose Rose → Send | Both see the Rose celebration (about 5 s); the chat line "🌹 … sent Rose to …"; A's balance drops by the price | | | [needs backend update] |
| GIFT-02 | — | Send each gift once | Each has its own animation; controls stay usable during it | | | |
| GIFT-03 | Insufficient balance | Try an expensive gift | "Not enough Diamonds" with Open wallet; no charge | | | |
| GIFT-04 | — | Double-tap Send quickly | Exactly one gift charged | | | |

## 7. Chat

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| CHAT-01 | A and B had a call | Message each other | Messages appear on both sides in real time | | | |
| CHAT-02 | — | Send "my number is 98…" | Not sent; "Keep conversations on Dashuri" notice | | | Contact filter |
| CHAT-03 | Airplane mode | Send a message | "Not sent · Tap to retry"; retry after reconnecting works | | | |
| CHAT-04 | B allows "People I've called" only | A (never called B) tries to message | "Accepts messages after a call" with Call instead | | | |
| CHAT-05 | Keyboard | Type a long message | The input stays above the keyboard; nothing hidden | | | |

## 8. Reels (off by default; only if a Reels-enabled build and R2 are configured)

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| REEL-00 | Default build | Look for a Reels tab | **No Reels tab** (flag off) | | | |
| REEL-01 | Reels build + R2 | Host uploads a 20 s clip | "Confirming your upload", then Processing, then Safety review | | | Needs R2 (not set up) |
| REEL-02 | REEL-01 approved | Customer scrolls the feed | Plays, mutes/unmutes, pauses on tap; the next reel starts instantly | | | |
| REEL-03 | Feed playing | Incoming call / switch tab / Home | The video stops | | | |

## 9. Notifications, permissions, lifecycle, network

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| LIFE-01 | Signed in | Force-stop, then reopen several times | Opens to the right home (customer or host) each time | | | |
| LIFE-02 | Host online | Switch to another app for 2 min, then return | Heartbeat resumes; still online, or "ended by server" if more than 90 s | | | |
| LIFE-03 | Any screen | Airplane mode on and off | Specific error titles ("Couldn't load …"); Try again recovers | | | |
| LIFE-04 | Slow network | Throttle (Developer options → or a weak signal) | Spinners, then content or a clear error; no frozen screens | | | |
| LIFE-05 | Rotation | Rotate on the call and profile screens | Layout adapts; no overflow stripes | | | |
| NOTIF-01 | — | Notifications bell | The in-app inbox loads | | | No push notifications in this build |
| PERM-01 | Fresh install | Permissions primer → Allow / deny each | Clear status (Needed / Allowed / Denied → Open settings) | | | |

## 10. Small screen, accessibility, compatibility

| ID | Preconditions | Steps | Expected | Actual | P/F | Notes |
|---|---|---|---|---|---|---|
| A11Y-01 | Smallest phone | Set Display size and Font size to the largest | Key screens (Discover, profile, call, wallet, Host Home) readable; no clipped buttons | | | |
| A11Y-02 | TalkBack on | Navigate Discover → profile → Buy Diamonds | Every button is announced with a sensible label; the balance is read once | | | |
| A11Y-03 | Remove animations (Accessibility) | Receive a gift / open Reels | Static banner instead of an animation; reels start paused | | | |
| A11Y-04 | Dark mode | Toggle the system dark theme | All screens readable | | | |
| COMP-01 | Each test phone | Run CALL-01–05 | Same results on both | | | |
| COMP-02 | Low-end phone | A 10-minute call | No overheating warning, no dropped frames that matter, no crash | | | |

## 11. Sign-off

| Area | Result | Blocking issues |
|---|---|---|
| Authentication | | |
| Payments | | |
| Calls | | |
| Host | | |
| Chat | | |
| Safety / reporting | | |
| Compatibility | | |

**Tester:** ______  **Date:** ______  **Build (versionCode / commit):** ______
