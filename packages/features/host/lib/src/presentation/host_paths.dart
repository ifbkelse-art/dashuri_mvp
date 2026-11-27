import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Host-internal paths that have no [RoutePaths] constant. They are children
/// of the host tab routes, so they keep the host shell visible.
abstract final class HostPaths {
  /// H13, child of [RoutePaths.hostDashboard].
  static const availability = '${RoutePaths.hostDashboard}/availability';

  /// H15, child of [RoutePaths.hostEarnings].
  static const beansExplainer = '${RoutePaths.hostEarnings}/beans';

  /// Beans history, child of [RoutePaths.hostEarnings].
  static const beansHistory = '${RoutePaths.hostEarnings}/history';

  /// Query flag marking a page as part of the application flow (FL04):
  /// saving continues to the next step instead of returning.
  static const flowParam = 'flow';
  static const flowApply = 'apply';

  /// Host Home query: `after=declined|missed|ended` shows a short notice
  /// after a call ("You're still online").
  static const afterParam = 'after';

  /// Host Home after a call: the notice says how the call ended.
  static String homeAfter(String how) =>
      '${RoutePaths.hostDashboard}?$afterParam=$how';

  /// Query flag for viewing the host agreement without the accept action.
  static const viewParam = 'view';

  static String inApplication(String path) => '$path?$flowParam=$flowApply';
}

/// Report action for a call row (V11/V12).
String hostReportLocation({
  required String userId,
  required String callId,
  String? name,
}) => Uri(
  path: RoutePaths.report,
  queryParameters: {
    'userId': userId,
    'callId': callId,
    if (name != null && name.isNotEmpty) 'name': name,
  },
).toString();
