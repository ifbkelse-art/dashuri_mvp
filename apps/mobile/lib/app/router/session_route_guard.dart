import 'dart:async';

import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';

/// Redirect rules: unknown → splash, signed out → sign-in,
/// signed in but not 18+ eligible → age gate. Minor protection is mandatory.
final class SessionRouteGuard extends ChangeNotifier implements RouteGuard {
  SessionRouteGuard(this._session) {
    _subscription = _session.stream.listen((_) => notifyListeners());
  }

  final SessionCubit _session;
  late final StreamSubscription<SessionState> _subscription;

  static const _public = {RoutePaths.splash, RoutePaths.signIn};

  @override
  String? redirect(GoRouterState state) {
    final location = state.matchedLocation;
    return switch (_session.state) {
      SessionUnknown() =>
        location == RoutePaths.splash ? null : RoutePaths.splash,
      SessionSignedOut() =>
        _public.contains(location) ? null : RoutePaths.signIn,
      final SessionSignedIn s when !s.ageEligible =>
        location == RoutePaths.ageGate ? null : RoutePaths.ageGate,
      SessionSignedIn() =>
        _public.contains(location) ? RoutePaths.discovery : null,
    };
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
