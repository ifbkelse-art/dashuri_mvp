/// Every navigable path in the app. Features navigate with
/// `context.go(RoutePaths.wallet)` instead of importing another feature.
///
/// Add a constant here when you add a page. Paths are part of deep-link
/// handling, so treat renames as breaking changes.
abstract final class RoutePaths {
  static const splash = '/';
  static const signIn = '/sign-in';
  static const ageGate = '/age-gate';

  static const discovery = '/discover';
  static const hostProfile = '/hosts/:userId';
  static const freeCall = '/free-call';

  static const call = '/calls/:callId';

  static const conversations = '/messages';
  static const conversation = '/messages/:conversationId';

  static const wallet = '/wallet';
  static const buyDiamonds = '/wallet/buy';

  static const myProfile = '/me';
  static const editProfile = '/me/edit';

  static const hostDashboard = '/host';
  static const hostEarnings = '/host/earnings';
  static const hostWithdraw = '/host/withdraw';

  static const report = '/report';
  static const blockedUsers = '/settings/blocked';
  static const notifications = '/notifications';
  static const settings = '/settings';

  /// Fills `:param` segments, e.g. `RoutePaths.withParams(RoutePaths.call, {'callId': id})`.
  static String withParams(String path, Map<String, String> params) =>
      params.entries.fold(
        path,
        (p, e) => p.replaceAll(':${e.key}', Uri.encodeComponent(e.value)),
      );
}
