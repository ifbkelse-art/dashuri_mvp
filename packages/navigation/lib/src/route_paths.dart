/// Every navigable path in the app. Features navigate with
/// `context.go(RoutePaths.wallet)` instead of importing another feature.
///
/// Screen ids (A01, C07, …) refer to the design handoff in
/// `design/Dashuri_Design`. Paths are part of deep-link handling, so treat
/// renames as breaking changes.
abstract final class RoutePaths {
  // Auth & onboarding (A01–A15).
  static const splash = '/'; // A01
  static const welcome = '/welcome'; // A02
  static const signIn = '/sign-in'; // A03/A04 phone entry
  static const verifyOtp = '/sign-in/verify'; // A05/A06
  static const ageGate = '/age-gate'; // A09/A10
  static const createProfile = '/onboarding/profile'; // A08 + A11 gender
  static const chooseExperience = '/onboarding/experience'; // A12
  static const communityRules = '/onboarding/rules'; // A13
  static const permissions = '/onboarding/permissions'; // A14/A15
  static const cityPicker = '/location/city'; // coarse city (F4)

  // Customer shell tabs (FL06).
  static const discovery = '/discover'; // C01–C06
  static const conversations = '/messages'; // CH01/CH03
  static const wallet = '/wallet'; // W01
  static const myProfile = '/me'; // S01

  // Customer detail screens.
  static const discoveryFilters = '/discover/filters'; // C03
  static const hostProfile = '/hosts/:userId'; // C07–C09, C12
  static const freeCall = '/free-call'; // C02/C10
  static const notifications = '/notifications'; // C11
  static const conversation = '/messages/:conversationId'; // CH02/CH04/CH05
  static const buyDiamonds = '/wallet/buy'; // W02
  static const checkout =
      '/wallet/checkout/:productId'; // W03/W04 (Play sheet or Cashfree)
  static const paymentResult = '/wallet/payment/:orderId'; // W05–W07
  static const transactions = '/wallet/transactions'; // W08
  static const giftsSent =
      '/wallet/gifts'; // customer gift history (2026-11-26)
  static const transactionDetail = '/wallet/transactions/:entryId'; // W09
  static const editProfile = '/me/edit'; // S02
  static const settings = '/settings'; // S03
  static const privacyMessaging = '/settings/privacy'; // S04
  static const notificationSettings = '/settings/notifications'; // S05
  static const blockedUsers = '/settings/blocked'; // S06
  static const helpSupport = '/settings/help'; // S07
  static const legal = '/settings/legal'; // S08
  static const deleteAccount = '/settings/delete-account'; // S09/S10
  static const enforcement =
      '/settings/account-status'; // enforcement notices + appeal

  // Calls (V01–V18), full-screen from any tab.
  static const preCall = '/hosts/:userId/call'; // V01/V06
  static const call = '/calls/:callId'; // V02–V05, V07, V15–V17
  static const callSummary = '/calls/:callId/summary'; // V08–V10, V14, V18
  static const report = '/report'; // V11/V12 (query: userId, callId)
  static const callHistory = '/calls'; // H22 + customer history

  // Host application (H01–H10).
  static const hostOnboarding = '/host/apply'; // H01/H02
  static const hostVerification = '/host/verification'; // H03–H05, H07/H08
  static const hostAgreement = '/host/agreement'; // H06
  static const hostProfileSetup = '/host/profile-setup'; // H09
  static const hostRate = '/host/rate'; // H10
  static const hostVerifiedHost =
      '/host/verified-host'; // Verified Host (2026-11-23)

  // Host shell tabs (FL06).
  static const hostDashboard = '/host'; // H11–H13
  static const hostCalls = '/host/calls'; // H22
  static const hostEarnings = '/host/earnings'; // H14/H15
  static const hostProfileTab = '/host/me'; // H23/H24

  // Host detail screens.
  static const hostWithdraw = '/host/withdraw'; // H16/H17/H18/H21/H25
  static const hostPayoutHistory = '/host/payouts'; // H19
  static const hostPayoutMethod = '/host/payout-method'; // H20
  static const hostSettings = '/host/settings'; // H24

  // Gifts received (2026-11-26); the summary lives on Host Home.
  static const hostGifts = '/host/gifts'; // received gifts history

  // EXPERIMENT — Dashuri Reels (registered only when DASHURI_REELS_ENABLED).
  static const reels = '/reels'; // customer-shell tab: vertical feed
  static const hostReels = '/host/reels'; // host-shell tab: the same feed
  static const reelDetail = '/reels/watch/:reelId'; // one reel
  static const reelCreator =
      '/reels/creators/:userId'; // creator profile ("me" = own)
  static const reelUpload =
      '/reels/upload'; // record / gallery → caption → status
  // Own reels (host mode). Full-screen, so it opens above the host shell
  // instead of jumping into the customer Reels tab.
  static const reelMine = '/my-reels';

  /// Fills `:param` segments, e.g. `RoutePaths.withParams(RoutePaths.call, {'callId': id})`.
  static String withParams(String path, Map<String, String> params) =>
      params.entries.fold(
        path,
        (p, e) => p.replaceAll(':${e.key}', Uri.encodeComponent(e.value)),
      );
}
