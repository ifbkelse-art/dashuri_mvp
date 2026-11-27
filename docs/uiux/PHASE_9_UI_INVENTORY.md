# Phase 9 UI inventory

**Written 27 Nov 2026 from the repository at `867f6b8`.** Every row comes from the route files (`packages/features/*/lib/src/routes/*_routes.dart`), `packages/navigation/lib/src/route_paths.dart` and the pages themselves.

**Visual baseline:** about 740 screenshots of the existing widget-test states. They were rendered at 390×844 with real fonts through `tool/uiux/audit_hook.dart` (`DASHURI_UIUX_SHOTS`), in light theme, plus dark for auth, discovery and wallet. This is rendering in the test engine, not device testing.

**Redesign priority:**
- P0: correctness or honesty problem visible in the UI.
- P1: high-traffic screen with a clear visual problem.
- P2: polish.
- P3: fine as is.

## 1. Navigation systems

| System | Where | Notes |
|---|---|---|
| Root `GoRouter` | `apps/mobile/lib/app/router/app_router.dart` | `appNavigatorKey` (27 Nov). Onboarding guard: `session_route_guard.dart`. |
| Customer shell | `role_shells.dart`, `StatefulShellRoute.indexedStack` | Tabs: Discover · (Reels, flag) · Messages · Wallet · Me. Pages persist (IndexedStack). |
| Host shell | same file | Tabs: Home · Calls · (Reels, flag) · Earnings · Profile. |
| Adaptive shell | `design_system/.../adaptive_shell.dart` | Bottom bar on phones, rail on wide windows. |
| App-wide overlays | `apps/mobile/lib/app/app.dart` | `IncomingCallWatcher` pushes the call screen from anywhere; purchase recovery binding. |
| Modal surfaces | Bottom sheets (arrival prompt, gift sheet, report, sort), dialogs (`showConfirmDialog`), snackbars (`showHostSnack`, feature snackbars) | |

## 2. Screens

Columns: package · route (screen ids) · page · state holder · data (API) · priority and observed problems.

### Auth and onboarding (`feature_auth`, `feature_profile`, `feature_safety`, `feature_location`)

| Route | Page | State | Data | Priority / problems |
|---|---|---|---|---|
| `/` A01 | SplashPage | SessionCubit | `GET /v1/me` | P3. Brand splash; error with Try again / Log out. |
| `/welcome` A02 | WelcomePage | — | — | P3. Good hero. |
| `/sign-in` A03/A04 | PhonePage | SignInCubit | Supabase OTP | P3. |
| `/sign-in/verify` A05/A06 | OtpPage | SignInCubit | Supabase OTP | P3. |
| `/age-gate` A09/A10 | AgeGatePage | AgeGateCubit | `POST /v1/me/age` | P3. |
| `/onboarding/profile` A08/A11 | CreateProfilePage | CreateProfileCubit | profile API | P3. |
| `/onboarding/experience` A12 | ChooseExperiencePage | ExperienceCubit | local | P3. |
| `/onboarding/rules` A13 | CommunityRulesPage | CommunityRulesCubit | consents | P3. |
| `/onboarding/permissions` A14/A15 | PermissionsPage | PermissionsCubit | OS permissions | P3. |
| `/location/city` | CityPickerPage | CityPickerCubit | location API | P3. |

### Customer core

| Route | Page | State | Data | Priority / problems |
|---|---|---|---|---|
| `/discover` C01–C06 | DiscoveryPage | DiscoveryCubit, DiscoveryHeaderCubit | `GET /v1/discovery/hosts`, summary, wallet, free-call card | P2. Clear hierarchy; card status and verified marks are small; error copy generic ("Couldn't load this"). |
| `/discover/filters` C03 | DiscoveryFiltersPage | (local) | — | P3. |
| `/hosts/:userId` C07–C09, C12 | HostProfilePage | HostProfileCubit | `GET /v1/discovery/hosts/{id}`, wallet | **P1.** Verified shown twice (title badge and "Verified Host" chip). The call button does not show the per-minute rate, which is only visible further down. The status row wraps awkwardly. |
| `/free-call` C02/C10 | FreeCallPage | FreeCallCardCubit, FreeCallMatchCubit | free-call API | P3 (no widget screenshots: tests are cubit-only). |
| `/notifications` C11 | NotificationsPage | InboxCubit | notifications API | P3. |
| `/hosts/:userId/call` V01/V06 | PreCallPage | PreCallCubit | host + wallet | P2. Fine; header avatar small. |
| `/calls/:callId` V02–V05, V07, V15–V17 | CallPage | CallBloc, GiftSheetBloc, GiftCelebrationCubit | calls API + Stream + realtime | **P0/P1.** The **failure state's action button is pale pink on black and looks disabled** ("End call" / "Close"). Report (flag) sits between Mute and End in the control pill, so an end tap can hit it. Info pills are fine. |
| `/calls/:callId/summary` V08–V10, V14, V18 | CallSummaryPage | CallSummaryCubit | call session | P3. |
| `/calls` | CallHistoryPage | CallHistoryCubit | history API | P3. |
| `/report` V11/V12 | report sheet / BlockConfirmPage | (safety) | safety API | P3. |

### Wallet and purchases

| Route | Page | State | Data | Priority / problems |
|---|---|---|---|---|
| `/wallet` W01 | WalletPage | WalletCubit | `GET /v1/wallet`, entries, `wallet.updated` | P3. Strong balance card. |
| `/wallet/buy` W02 | BuyDiamondsPage | PurchaseBloc | packages + Play prices | **P1.** Package cards **truncate the talk-time line** ("≈ 22 min with An…"). The current-balance pill reads as a disabled field. |
| `/wallet/checkout/:productId` W03/W04 | CheckoutPage | PurchaseBloc | Play / Cashfree | P3. Honest "Diamonds are added only after the payment is verified". |
| `/wallet/payment/:orderId` W05–W07 | PaymentResultPage | (result) | server order | P3. |
| `/wallet/transactions` W08 | TransactionHistoryPage | WalletHistoryCubit | entries | P3. |
| `/wallet/transactions/:entryId` W09 | TransactionDetailPage | — | entry | P2. Date value wraps; the help row title is oversized. |
| `/wallet/gifts` | SentGiftsPage | SentGiftsCubit | gifts API (flag) | P3. |

### Chat (`feature_chat`)

| Route | Page | State | Data | Priority / problems |
|---|---|---|---|---|
| `/messages` CH01/CH03 | ConversationsPage | ConversationsCubit | chat API + realtime | P3. |
| `/messages/:id` CH02/CH04/CH05 | ConversationScreen | ConversationCubit | chat API + realtime | P3. Pending, failed and retry, contact-filter notice and restricted states are already clear. |

### Settings, safety, profile

| Route | Page | State | Data | Priority / problems |
|---|---|---|---|---|
| `/me` S01 | MyProfilePage | MyProfileCubit | profile | P3. |
| `/me/edit` S02 | (profile edit) | — | profile | P3. |
| `/settings` S03 | SettingsPage | SettingsCubit | — | P3. Grouped well. |
| `/settings/privacy` S04 | PrivacyPage | PrivacyCubit | privacy API | P3. |
| `/settings/notifications` S05 | NotificationSettingsPage | ConsentsCubit | consents | P3. |
| `/settings/blocked` S06 | BlockedUsersPage | BlockedUsersCubit | safety | P3. |
| `/settings/help` S07 | HelpSupportPage | GrievanceCubit | grievance API | P3. |
| `/settings/legal` S08 | LegalPage | — | bundled texts | **P0 (content, founder decision):** "placeholders, not legally binding" banner while the website has v1.0. |
| `/settings/delete-account` S09/S10 | DeleteAccountPage | DeleteAccountCubit | deletion API | P3. |
| `/settings/account-status` | EnforcementPage | EnforcementCubit | appeals | P3. |

### Host (`feature_host`)

| Route | Page | State | Data | Priority / problems |
|---|---|---|---|---|
| `/host` H11–H13 | HostDashboardPage | HostSessionBloc, HostDashboardCubit, ArrivalPhotoCubit, HostGiftsCubit | host status, heartbeat, earnings, arrival | P2. Clear offline/online card and session states. |
| `/host/availability` | HostAvailabilityPage | HostDashboardCubit | host status | P3. |
| `/host/calls` H22 | HostCallsPage | HostCallsCubit | history | P3. |
| `/host/earnings` H14/H15 | HostEarningsPage | HostEarningsCubit | `GET /v1/host/earnings` | **P0.** A prominent gold **"Withdraw ₹621.50"** button while payouts are off: the host only learns "Withdrawals are coming soon" after entering an amount and submitting. This implies money can be withdrawn. |
| `/host/withdraw` H16–H18, H21, H25 | HostWithdrawPage | HostWithdrawCubit | withdrawals API | P0 (same issue). |
| `/host/payouts` H19, `/host/payout-method` H20 | payout history / method | HostPayoutsCubit | payouts | P3. |
| `/host/me` H23/H24 | HostProfileTabPage | HostProfileTabCubit | profile | P3. |
| `/host/rate` H10 | HostRatePage | HostRateCubit | rate API | P3. |
| `/host/verified-host` | VerifiedHostPage | VerifiedHostCubit | verification | P3. |
| `/host/apply`, `/host/verification`, `/host/agreement`, `/host/profile-setup` H01–H09 | onboarding pages | application/verification cubits | host API | P3. |
| `/host/settings` H24 | HostSettingsPage | — | — | P3. |
| `/host/gifts` | HostGiftsPage | HostGiftsCubit | gifts (flag) | P3. |
| arrival prompt sheet + `ArrivalCameraPage` | arrival_flow.dart, in_app_arrival_camera.dart | ArrivalPhotoCubit | arrival API | P3 (new 27 Nov). |

### Reels (`feature_reels`, flag off)

| Route | Page | State | Priority |
|---|---|---|---|
| `/reels`, `/host/reels`, `/reels/watch/:id` | ReelsFeedPage | ReelsFeedCubit | P3 (rebuilt 27 Nov: player, buffering, error and retry, reduced motion). |
| `/reels/creators/:userId`, `/my-reels` | CreatorProfilePage | CreatorProfileCubit | P3. |
| `/reels/upload` | ReelUploadPage | ReelUploadCubit | P3 (fixed 27 Nov: "Confirming your upload"). |

## 3. Shared states (design system, `packages/design_system`)

| State | Component | Observed |
|---|---|---|
| Loading | `LoadingView`, skeleton grids | Good (discovery skeleton). |
| Empty | `EmptyStateView` | Good, consistent icon-in-circle plus serif title. |
| Error | `ErrorStateView` (+ `.withAction`) | Consistent; copy is often the generic "Couldn't load this". **The `.withAction` button on dark call screens looks disabled.** |
| Confirm | `showConfirmDialog` | Fine. |
| Money | `BalancePill`, `CurrencyAmount`, `DiamondIcon`, `BeanIcon` | Consistent. |
| Status | `StatusTag` (online, busy, offline, success, warning, error) | Consistent. |

## 4. Not covered by screenshots

- Free Call Card (cubit tests only).
- Profile edit.
- Notifications inbox detail.
- Real video frames (tests use coloured boxes).
- Real photos (tests show initials).

Device review is still required (no `adb` on the build Mac).
