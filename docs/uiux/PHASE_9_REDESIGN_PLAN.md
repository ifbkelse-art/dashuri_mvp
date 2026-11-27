# Phase 9 redesign plan

Started 27 Nov 2026 on `feat/calls-720p-and-app-icon` after `867f6b8`. Status: **in progress**. This file is updated as work lands. Inventory: `PHASE_9_UI_INVENTORY.md`. Ideas that are out of scope: `PHASE_9_FUTURE_IMPROVEMENTS.md`.

## 1. Audit findings (summary)

The app already has a coherent design language from the 19 Nov handoff and the 23 Nov UI/UX pass:
- burgundy primary and warm neutrals;
- a serif display face over a clean sans;
- pill buttons and an M3 theme;
- a contrast-audited dark mode;
- shared empty, error and loading views.

It does not look like a template. Phase 9 therefore **refines this system and fixes real problems**. Restyling everything would risk regressions for little visual gain.

Problems found, by severity:

| Sev | Problem | Screen |
|---|---|---|
| ~~P0~~ | ~~The error-state action renders pale pink on black and looks disabled.~~ **Not a defect on closer review:** it is the dark theme's standard primary button (tone-80 fill, dark label), the same as "Refresh" in dark Discovery, and it is legible. No change. | Call screen failure states |
| P0 | A prominent "Withdraw ₹…" button while payouts are off. "Coming soon" only shows after the host submits an amount. | Host Earnings, Withdraw |
| P1 | Report (flag) sits between Mute and End in the call controls, so it is easy to hit by mistake. | Call screen |
| P1 | Verified shown twice; the call button doesn't show the rate; the status row wraps. | Host profile |
| P1 | The talk-time line in package cards is truncated ("≈ 22 min with An…"); the balance pill reads as a disabled field. | Buy Diamonds |
| P2 | The date wraps and the help row title is oversized. | Transaction detail |
| P2 | Error copy is generic in places ("Couldn't load this"). | Several |
| Content | The legal page says "placeholders, not legally binding" while the website has v1.0. **Founder decision; not changed.** | Settings → Legal |

## 2. Principles

1. **Honest first.** Never show money, availability or success the server hasn't confirmed.
2. **Calm, premium, human.** Warm neutrals, one confident accent (burgundy), gold only for value (Diamonds, Beans, premium). No neon, no casino effects.
3. **Media screens are dark and immersive** (call, reels, incoming). Everything else is light, with an equally good dark mode.
4. **Critical actions are unmistakable** (End call, Accept, Go online, Buy). Destructive or secondary actions are separated from them.
5. **Motion is short and purposeful** (150–400 ms, standard easing), and switched off under reduced motion.

## 3. Design system (existing, documented; additions marked NEW)

Source: `packages/design_system` (tokens `dashuri_tokens.dart`, tones `dashuri_colors.dart`, type `dashuri_text.dart`, theme `dashuri_theme.dart`, components `components/*`).

**Colour (semantic):**

| Role | Light | Dark |
|---|---|---|
| Primary | burgundy700 | burgundy300 tone |
| Surface / background | neutral25 / neutral50 | neutral950 / neutral900 |
| Text | neutral900, secondary neutral600 | neutral50 / neutral300 |
| Success / warning / error / info | tokens and `*Text` variants | `DashuriColors` tones |
| Value | gold (Diamonds, Beans, premium) | gold |
| Online / busy / offline | `online` green, warning, neutral | same |
| On media | `DashuriColors.onMedia` + `mediaScrim` | same |

**Type:** a serif display (titles, money hero numbers) and a sans body/label (`DashuriText`), with the M3 roles display, headline, title, body and label. No new sizes.

**Spacing:** `space1`…`space10` (4–40). **Radii:** 8 / 12 / 20 / 28 / pill. **Tap target:** 48. **Content width:** 560 single column, 1200 wide.

**Motion:** `motionShort` 150, `motionMedium` 250, `motionLong` 400 ms, with M3 standard easing from the theme. No new token was needed in this batch.

**Components** (existing): `PrimaryButton`, `BalancePill`, `CurrencyAmount`, `StatusTag`, `UserAvatar`, `VerifiedHostBadge`, `EmptyStateView`, `ErrorStateView`, `LoadingView`, `InfoBanner`, `ResponsiveCenter`, `TwoPane`, adaptive shell; call: `RoundControl`, `CallControlsBar`. No duplicate components were created. New ones are added only where a real gap appears.

## 4. Order of work

| Batch | Scope | Status |
|---|---|---|
| 9A | Foundation review: tokens, theme, type, spacing, motion and components are already consistent across packages. No new primitives were needed. | **Done (review)** |
| 9B-1 | Call screen: Report moved first, End last, with an extra gap when it fits (the one-row guarantee on 360-pt phones is kept). | **Done** |
| 9B-2 | Host Earnings and Withdraw honesty: `DASHURI_PAYOUTS_ENABLED` (default off). No Withdraw button, "Available" not "Withdrawable", a plain note; Withdraw opens directly on "coming soon". | **Done** |
| 9B-3 | Host profile: verified shown once; rate on the call button ("Video call · 2,400 / min"); status row no longer wraps. | **Done** |
| 9B-4 | Buy Diamonds: talk-time hint wraps instead of truncating; balance shown as a plain labelled row. | **Done** |
| 9B-5 | Transaction detail. The screenshot was the 1.3× text-scale variant, which is correct large-text behaviour. | **No change** |
| 9C-1 | Visual review of every changed screen, light and dark, at 390×844 | **Done** |
| 9B-6 (`01f98ac`) | Discovery: one rate format ("2,400 / min") everywhere; specific error titles; a removed profile (404) says "Profile not available" with no dead-end retry | **Done** |
| 9B-7 (`975cc2c`) | Host Home: removed the "Free calls on/off" chip that duplicated the switch below it; specific error titles on all host screens | **Done** |
| 9B-8 (`c6a7b08`) | Chat: reviewed (bubbles, sending, not sent/retry, filters, composer already met the bar); specific error titles | **Done** |
| 9B-9 (`56895c7`) | Settings, profile, safety, notifications: reviewed; specific one-line error titles | **Done** |
| 9B-10 (`cd4e732`) | Onboarding: reviewed screen by screen, no change needed; city picker and Free Call Card error titles | **Done** |
| 9B-11 (`dea665d`) | Every `ErrorStateView` in the app now has a specific title (wallet, calls, Buy Diamonds, Reels creator) | **Done** |
| 9C-2 | Full sweep at 320/360/tablet and text ×1.3/×2.0, contrast audit | pending |

Each batch:
1. Read the page, its BLoC and data.
2. Change the presentation only.
3. Update or add widget tests.
4. Run the package tests.
5. Take screenshots and review them.

## 5. Risks

| Risk | Mitigation |
|---|---|
| Visual changes break the many existing widget tests (copy/finder based) | Keep copy and keys unless the change is the point; update tests only where the UI intentionally changed, and say so. |
| Call-screen changes affect the call lifecycle | Presentation only; `CallBloc` events untouched; call tests run each batch. |
| Payout honesty needs to know that payouts are off | App-side flag `DASHURI_PAYOUTS_ENABLED` (default off), no backend contract change. Payouts stay server-enforced. |
| No physical device | Screenshot review in the test engine at several sizes and themes; device pass still required. |

## 6. Completed / pending / known issues

**Completed (27 Nov):** 9A review; 9B-1 to 9B-4; 9C-1. Tests updated only where the UI intentionally changed:
- the profile call button label;
- new tests for the payouts-off Earnings and Withdraw states;
- End-call spacing.

Fresh `scripts/validate.sh`: passes (1,443 Flutter tests).

**Files:**
- `video_call`: `call_page.dart`, `call_widgets.dart`, `call_chat_test.dart`.
- `host`: `host_earnings_page.dart`, `host_withdraw_cubit.dart`, `host_module.dart`, `host_routes.dart` + tests.
- `core`: `app_config.dart`.
- app: `injector.dart`.
- `discovery`: `host_profile_page.dart` + test.
- `purchases`: `package_card.dart`, `buy_diamonds_page.dart`.

**Known issues:**
- Legal page draft banner (founder decision).
- No device pass yet.
- Turning payouts on requires both `PAYOUTS_ENABLED` on the server and `DASHURI_PAYOUTS_ENABLED` in the app build.
