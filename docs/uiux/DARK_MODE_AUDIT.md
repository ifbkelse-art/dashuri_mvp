# Dark Mode and contrast audit (23 Nov 2026)

Target: WCAG 2.2 AA in light **and** dark — 4.5:1 normal text, 3:1 large
text, icons and meaningful borders. Disabled controls are exempt (WCAG).

## Method

1. **Numbers first.** Every ColorScheme role and every status tone was
   measured (`packages/design_system/test/theme_contrast_test.dart`).
2. **Every screen with a widget test, in both themes.** The opt-in audit
   hook (`tool/uiux/audit_hook.dart`) gained:
   - `DASHURI_UIUX_THEME=dark` — all feature pump helpers render dark;
   - `DASHURI_UIUX_CONTRAST=<log>` — after each pump, every visible text is
     checked against the colour actually painted behind it (decorated and
     coloured boxes, Material, `Ink`, chip fills, Stack layers, alpha
     blending; gradients at their worst stop; skipped over images/video).
   All 14 feature packages were run in light and dark (28 full runs).
   Run it yourself, e.g.:
   `cd packages/features/wallet && DASHURI_UIUX_THEME=dark DASHURI_UIUX_CONTRAST=/tmp/c.log flutter test`

## Theme changes

- New `DashuriColors` ThemeExtension (`design_system/lib/src/theme/dashuri_colors.dart`):
  semantic **success / warning / error / info / neutral** tones
  (container, onContainer, icon) with separate light and dark values, plus
  `positiveText`, `onlineDot`, and fixed `onHero` / `onMedia` / `mediaScrim`
  palettes. Rule: status colours come from here, surfaces/text from the
  ColorScheme, raw `DashuriTokens` colours only for fixed-background art.
- ColorScheme fixes: dark `onSecondary` (3.1 → 6.2:1), dark `tertiary`
  (3.1 → 10.4:1), `outline` neutral-300/600 → neutral-500 (borders 1.6/2.9
  → ≥ 3:1), `secondary` gold slightly deepened (light) / brightened (dark),
  light `onSecondaryContainer` (4.2 → 5.8:1), `surfaceContainerHighest`
  adjusted in both modes.
- Inputs: enabled border uses `outline` (the fill is nearly the page
  colour, so the border is what shows the field); error/disabled borders
  and hint colour defined.

## Issues found and fixed

| Where | Problem | Fix |
|---|---|---|
| Payment result info box, checkout notices | default (light) text on a fixed pastel tint → **invisible in dark** | tone container + onContainer |
| Host dashboard "online" card | fixed light green card with theme text and chips → unreadable in dark; white "Go offline" button with light text | tone colours; surface-coloured button; AA green button |
| StatusTag, InfoBanner, HostNotice | fixed light tints in dark; HostNotice text 3.0/3.7:1 even in light | tones |
| Chat failed/"Not sent" text, CH05 notice | token red 3.1:1 on dark | `scheme.error`, error tone |
| Wallet "+amount", host calls earnings | success green 2.7–3.0:1 on dark | `positiveText` |
| Host onboarding label | gold 3.9:1 on dark | `scheme.secondary` |
| Safety, call summary, wallet icons, reel upload | fixed tints | tones |
| Call low-balance banner | white on orange 3.45:1 | AA warning colour |
| Call "FREE MINUTE" pill | white on gold 3.1:1 | goldDark |
| Call header name/type | white on raw video, no backing | text shadows |
| Host profile app-bar icons | 40 % scrim: 2.9:1 over a white photo | 55 % scrim |
| Discover online dot | 2.1:1 on light | `onlineDot` |
| Reels tabs over video | white label on any frame | translucent backing |

## Verified

- Design system: 29 tests — role/tone numbers in both themes; a gallery of
  cards, buttons (incl. disabled), inputs (label, hint, helper, error),
  chips (selected/unselected), status tags, banners, navigation bar,
  dialog and bottom sheet rendered in light and dark with zero contrast
  findings; switching light → dark → light and following the system
  setting update text and tones with no stale colours.
- Final sweep: all 28 runs pass. Remaining log lines are known false
  positives: text at the bottom of photo/placeholder cards measured against
  the gradient's top stop; test-only fake video tiles; the decorative red
  "live" dot next to the call timer; the host-profile app-bar icon (its
  scrim is in another Scaffold slot the auditor can't relate).

## Not done / limits

- The app follows the **system** theme (MaterialApp `theme` + `darkTheme`).
  There is no in-app Light/Dark/System picker, so there is no stored
  preference to persist; adding one is a product decision.
- Screens without widget tests were reviewed by code search only.
- Rendering checks run in the Flutter test engine, not on a device.
