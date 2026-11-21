import 'package:go_router/go_router.dart';

/// Each feature exposes its routes through this contract; the app's router
/// concatenates them. Features never construct the GoRouter themselves.
abstract interface class FeatureRoutes {
  List<RouteBase> get routes;
}

/// Decides where an unauthenticated or ineligible user is sent. Implemented
/// in the app, which knows the session and age-eligibility state.
abstract interface class RouteGuard {
  /// Returns a redirect path, or null to allow navigation.
  String? redirect(GoRouterState state);
}

/// Implemented by features that own a root tab of a role shell (FL06).
/// [tabRoutes] are placed inside the shell's branch for that tab (they keep
/// the navigation bar/rail visible); [FeatureRoutes.routes] stay full-screen.
abstract interface class TabFeatureRoutes implements FeatureRoutes {
  List<RouteBase> get tabRoutes;
}
