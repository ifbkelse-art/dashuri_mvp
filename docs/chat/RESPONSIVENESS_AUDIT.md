# Responsiveness audit — experimental work (22 Nov 2026)

Scope: every screen the experiment adds or changes:
- Normal Chat (CH02);
- the Inbox (CH01);
- the in-call chat panel;
- the video-call screen (CallPage);
- Reels (feed, creator profile, upload).

**Method: automated widget tests only.** No emulator or physical device was
run for this audit. **This is not device verification** (see §6).

## 1. Matrix

| Dimension | Values |
|---|---|
| Viewports | 320×568, 360×800, 390×844, 412×915, 1024×1366 (tablet), 844×390 (landscape phone) |
| Text scale | 1.0, 1.3, 2.0 |
| System insets | notch/status bar 47 px top, home indicator 34 px bottom. While the keyboard is up, the bottom padding is consumed, as on real devices |
| Keyboard | 40% of the window height, opened and closed during the test |
| Content | 60-character display names, 1,000-character messages, a 300-character string with no break points, 900-character drafts, emoji, 9-digit currency figures, a long low-balance banner, unread counts |

**Checks in every case** (helpers `test/**/layout_audit.dart`):
- **Layout errors fail the test.** Any RenderFlex/RenderBox overflow,
  unbounded constraint or layout exception fails it automatically.
- **Text stays on screen.** Every rendered text's transformed rect stays
  inside the window horizontally, so nothing is clipped off-screen and there
  is no horizontal overflow.
- **Controls are reachable.** Essential controls (Send, composer, End call,
  every call control, the chat panel, Close chat, Try again) are fully on
  screen and above the keyboard.
- **Touch targets.** Call controls are at least 48 px.
- **Chat layout.** The chat panel ends above the call controls. The newest
  message's last line is visible above the composer.

## 2. Screens and cases

| Screen | Cases | Result |
|---|---|---|
| Normal Chat: long content; keyboard open; long draft; send with keyboard open | 18 | pass |
| In-call panel at 120 / 150 / 240 / 420 px tall | 18 (×4 heights) | pass |
| Inbox: long names and previews | 18 | pass |
| Call screen, chat closed (all controls, ≥48 px, low-balance banner) | 18 | pass |
| Call screen, chat open (panel between top bar and controls) | 18 | pass |
| Call screen, typing (composer above keyboard; controls back after) | 18 | pass |
| Reels: all 10 responsive page tests, now run across the full matrix (previously 3 configurations each) | 180 | pass |
| Extra: panel failed state at 160 px, 2×; "During video call" label and Sent → Read | 2 | pass |

## 3. Issues found and fixed

| # | Where | Problem found by the audit | Fix |
|---|---|---|---|
| 1 | Call control bar | `FittedBox` scaled 5–6 controls down to ~38 px on small phones (below a usable touch target, and hid the problem) | Constraint-based bar: 56 px, shrinking to no less than 48 px; wraps to a second row on 320 px |
| 2 | Call screen | Top bar and controls were independent overlays: on short landscape screens they could overlap, and a chat panel would have had no safe place | One column (top bar → panel → controls). The top bar is height-capped and scrolls on 640×360 and 844×390 |
| 3 | Chat bubbles | Width came from the **screen** (`MediaQuery` × 0.75), which is wrong inside a narrower panel or split pane | Width comes from the parent's constraints (80%) |
| 4 | Chat meta line | Fixed `Row` (status + time) could overflow at 2× | Wrapping text inside the bubble width |
| 5 | Normal Chat (pre-existing) | Landscape with the keyboard open: a 5-line composer overflowed by up to 71 px | Composer line limit shrinks with the visible height (≤ 1/5 of it) |
| 6 | In-call panel | At 2× text in a small panel: the header + composer didn't fit, so Send was clipped | Compact-mode threshold grows with text size; compact mode keeps the Send row in view |
| 7 | In-call panel | In compact mode a failed state showed only the header, hiding the reason and "Try again" | Compact mode shows the state body (scrollable) |
| 8 | Reels feed (pre-existing in the experiment) | Creator name had a fixed 180 px width: overflow of 16–37 px at 320 px/1.3× and in landscape | `Flexible` name with ellipsis |
| 9 | Reels creator profile (pre-existing) | "Video call · 1,500 Diamonds/min" button label couldn't wrap: up to 143 px overflow at 2× | Label wraps inside the button |
| 10 | Design system `StatusTag` (pre-existing, shared) | Label in a non-flexible `Row`: long tags ran off screen at 2× | Dot-less tags are a single wrapping `Text`. Tags with a dot (short availability labels) are unchanged. Safe inside `FittedBox` (no `Flexible` with unbounded width) |
| 11 | Test harness | The bottom safe-area inset was kept while the keyboard was open (unrealistic), producing false overflows | Harness consumes it while the keyboard is up, as Android/iOS do |

After the fixes: **0 overflow or layout exceptions** in the matrix.

## 4. Tests executed (actual results)

| Suite | Result |
|---|---|
| `feature_chat` (incl. 56 responsive cases) | 104 passed |
| `feature_video_call` (incl. 54 responsive cases) | 182 passed |
| `feature_reels` (incl. 180 responsive cases) | 212 passed |
| All 20 Flutter packages | **1,163 passed, 0 failed** |
| `scripts/validate.sh` (format, analyze, dependency rules, Dart tests, Go vet/race/build, migrations + invariants) | **All checks passed** |

## 5. Not covered / remaining limitations

**Not audited:**
- Existing screens outside the experiment (onboarding, wallet, host
  wizard…) were not re-audited. Only the shared `StatusTag` change touches
  them, and their suites still pass.
- Reels' upload page is covered by its existing tests in the new matrix.
  Playback itself still needs `video_player` (founder approval), so video
  scaling is untested with a real player.

**Not modelled:**
- Side insets for landscape notches.
- Foldables' hinge.
- RTL.

**By design:**
- While the chat panel is open, the self-view tile is hidden.
- While typing, the call controls give way to the keyboard.
- On 320 px phones the call controls wrap to two rows.

## 6. Manual device verification — still to do

Not performed in this session. Suggested pass on a small phone (≤ 360 dp) and
a large one, with system font size at maximum:
1. In-call chat, open and closed, with the keyboard.
2. Normal Chat with long messages.
3. Reels feed and creator profile.
4. The call screen in portrait and landscape.
