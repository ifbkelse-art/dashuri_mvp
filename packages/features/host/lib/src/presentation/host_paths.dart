import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Host-internal paths that have no [RoutePaths] constant. They are children
/// of the host tab routes, so they keep the host shell visible.
abstract final class HostPaths {
  /// H13, child of [RoutePaths.hostDashboard].
  static const availability = '${RoutePaths.hostDashboard}/availability';

  /// H15, child of [RoutePaths.hostEarnings].
  static const beansExplainer = '${RoutePaths.hostEarnings}/beans';

  /// Query flag marking a page as part of the application flow (FL04):
  /// saving continues to the next step instead of returning.
  static const flowParam = 'flow';
  static const flowApply = 'apply';

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
