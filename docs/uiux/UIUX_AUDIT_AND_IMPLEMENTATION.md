# Dashuri UI/UX pass — audit and implementation report (23 Nov 2026)

**Status: this pass is complete as far as automated verification can take
it.** Physical-device verification is still to do (§8).

Committed on 2026-11-23 (see git history). No deployment, database change or
paid service was involved.

**Scope of the commit:** everything in this report except the changes to the
Reels screens and the Reels-only tests. Dashuri Reels is a separate,
uncommitted experiment; the fixes this pass made inside it (creator profile,
upload guidance, status-tag sheet) stay with that experiment. The restore kit
described in §1 (`docs/uiux/experiment`) is a local safety net and is not part
of the commit; to undo the committed changes, revert the commit.

## 1. Safety and recovery

**Baseline:**
- Branch `feat/calls-720p-and-app-icon`, HEAD `03ba816` (unchanged).
- 1,631 files hashed, including the uncommitted Reels experiment and
  `docs/finance`: `docs/uiux/experiment/BASELINE.md`,
  `baseline_files.sha256`.

**Change record:**
- Every changed file was backed up before its first edit: 61 files
  (`MODIFIED.txt` + `backup/`).
- 2 paths were created (`CREATED.txt`). Nothing was deleted (`DELETED.txt`).
- `check_coverage.sh` confirms that every changed or new file is recorded.

**Restore:**
- `docs/uiux/experiment/restore.sh --apply` uses no git.
- **Verified on a full scratch copy:** every one of the 1,631 files matched the
  baseline afterwards.

**Discarding everything:** run this pass's `restore.sh --apply` first, then the
Reels kit's (`docs/reels/experiment/restore.sh`).

## 2. Method

**1. Read the app.**
- Design system: tokens, M3 theme, shared components and state views.
- Navigation and route guards; BLoC structure.
- Inventory: 58 screens in 15 feature packages.

**2. Audit hook (`tool/uiux/audit_hook.dart`, test-only).**
- Called from every package's pump helper; it does nothing unless
  `DASHURI_UIUX_*` is set.
- It re-runs all ~1,180 existing widget tests under forced conditions:
  - window size and text scale;
  - notch insets;
  - an optional open keyboard.
- It logs every layout error with its source location, even when a test
  swallows it.
- It can render real fonts and save screenshots.

**3. Sweeps run:**

| Window | Text | Fonts | Keyboard | Result after fixes |
|---|---|---|---|---|
| 320×568 | 2.0× | test font (1 em per glyph, stress) | – | 1 remaining (see §7) |
| 320×568 | 2.0× | real | – | **0** |
| 360×800 | 1.3× | real | – | **0** |
| 844×390 landscape | 1.0× | real | – | **0** |
| 1024×1366 tablet | 1.0× | real | – | **0** |
| 360×800 | 1.3× | real | 40% | **0** |
| 320×568 | 2.0× | real | 40% | **0** |

**4. Visual review.**
- 664 screenshots (470 distinct states) at 390×844 with real fonts.
- Tiled into contact sheets and reviewed screen by screen.
- This is rendering in the test engine, **not device testing**.

## 3. Bugs and UX friction fixed

| Problem | Fix |
|---|---|
| A failed call join reverted to a permanent **"Connecting securely…"** and silently re-joined media on every poll | The failure screen stays (with "End call") until the server reports a terminal phase; its message is kept. Regression test added. |
| **Chats inbox didn't refresh** after reading a conversation | Quiet re-fetch on return. Test added. |
| Host wizard said **"Save rate … next call"** before approval | "Continue" plus "applies once you are approved". Test updated. |
| A newly **approved host needed an app restart**; "Go to host home" bounced to Discover | The account is re-read when the app resumes (a failure keeps the current account, never a bounce to the splash). "Go to host home" refreshes and selects host mode (`HostModeEnter` port). Tests added. |
| "Applications closed" error shown in a **SnackBar that could appear off screen** and vanished | Shown inline above the button, and stays. |
| Reels upload **guidance looked like a second error** (burgundy info ≈ red error) | Info tone now uses the token info blue, consistent with `HostNotice`. |
| Transaction history error said "couldn't load your **wallet**" | Says "your activity" / "this transaction" on those screens. |
| Chats header **privacy icon was a filter glyph** | Same icon as "Who can message me" in Settings. |
| Error title **"Something went wrong" over "You're offline"** | Neutral default title: "Couldn't load this". |

## 4. Accessibility fixed

**Contrast (measured):**
- **Selected chips were unreadable** (`FilterChip`: dark label on the dark
  fill; Edit profile and host profile languages). The theme label colour is
  now state-aware.
- **Warning and success text failed WCAG AA:** 3.0:1 and 3.7:1 in banners and
  status tags. New text tokens `warningText`/`successText` measure 5.5:1 and
  5.6:1; icons keep the base colours.
- Green amount text on the page background measured 4.0:1 and now uses the
  AA-safe green.
- Tests: `packages/design_system/test/chip_contrast_test.dart` checks chip
  labels and every `InfoBanner` tone at 4.5:1 or better.

**Other:**
- **Touch targets:** call controls are at least 48 px (from the earlier chat
  pass).
- **Reduced motion:** the new skeleton is static when the system asks for
  reduced motion.
- **Screen readers:** the skeleton announces "Loading". The `HostLinkTile`
  rebuild keeps button semantics.

## 5. Responsive and layout fixes

**Shared components** (each fixes many screens):
- **`CurrencyAmount`** wraps (a single text with an inline glyph). It is safe
  inside `FittedBox` and `IntrinsicHeight`, where `Flexible` or
  `LayoutBuilder` would throw.
- **`showConfirmDialog`** and the Reels appeal dialog are scrollable.
- **`FormPageBody`** and **`HostBottomBar`**: the pinned actions are capped at
  45% of the real available height and scroll inside. `FormPageBody` measures
  with `LayoutBuilder`, because Scaffold hides the keyboard inset from
  `MediaQuery`.
- **New `LabelValueRow`:** the label takes the rest of the row and the value
  sits at the end with its natural width, capped and wrapping. It replaced an
  `Expanded` + `Flexible` pattern that split rows in half. The screenshots
  exposed that regression from this pass ("Recommended" floating mid-row);
  it is now fixed in 9 places.
- **`HostLinkTile`** was rebuilt (the `ListTile` asserted "trailing consumes
  the entire tile width").
- **`BalancePill`** text grows to 1.5× only, so a balance never truncates.
- **`StatusTag`** wraps (earlier pass).

**Screens:**
- **Chat:** the conversation's notices share space with messages; the
  restricted view scrolls.
- **City picker:** one `CustomScrollView`, so the warning no longer hides
  results or "Open settings".
- **Checkout:** the payment-method sheet scrolls; prices are capped.
- **Host:** dashboard, withdraw confirmation, verification, availability,
  payout history, photo "In review" tile.
- **Wallet:** transaction rows and detail.
- **Profile:** level chip and level progress.
- **Safety:** age gate, enforcement.
- **Discovery:** sort control.
- **Reels:** status-tag sheet.

## 6. Interaction quality

- **`SkeletonList`** (design system) is now on all list screens' first load:
  Inbox, notifications, call history, transactions, payout history, host
  calls, blocked users. Discover already had a matching skeleton grid.
- **Haptics:** medium impact on accept, decline and end call; a light click on
  sending a message. No new dependency.
- **Checked and intact:**
  - loading, empty, error and success states on every screen;
  - confirmation for destructive actions (delete account, block, unblock, sign
    out, withdraw, report-and-end-call, delete reel).

## 7. Verification (actually run)

- **`scripts/validate.sh`: All checks passed (exit 0).** This covers format,
  analyzer, dependency rules, all Dart/Flutter tests, Go vet/race/build, and
  the migrations with every invariant.
- **Flutter: 1,187 tests passed, 0 failed, across 21 packages** (1,163 before
  the UI/UX work, 879 before the chat/Reels work).
- **Layout sweeps:** see §2. Two known residuals:
  - The Discover header (title + balance + bell) overflows **only with the
    1-em stress font** at 320 px / 2×. With real fonts it fits. Truncating a
    balance would be worse, so it is left as is.
  - Three test helpers (wallet, purchases, chat pages) build their
    `MediaQuery` by hand, so the keyboard sweep doesn't reach those pages.
    Chat's keyboard behaviour has its own responsive tests.

## 8. Remaining: physical-device verification

Not done; no emulator or phone was used. Recommended pass on a small phone
(≤360 dp) and a large one, with system font size and display size at maximum:
1. Call screen: incoming, connecting, active, the chat panel with the
   keyboard, and a forced join failure (should stay on the failure screen).
2. Host approval: approve while the app is in the background, then return
   (should enter host mode without a restart).
3. Chat inbox: read a conversation and come back (unread badge clears).
4. Onboarding forms with the keyboard: phone, OTP, birthday, profile.
5. Wallet, checkout sheet, withdraw confirmation.
6. Reels feed, creator profile, upload.
7. Haptics feel (Android vibration settings).

Fonts on devices are Manrope and Instrument Serif via google_fonts, slightly
wider than the Roboto used in the sweeps. That is another reason for the
device pass at maximum font size.
