import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';

/// Pages a signed-out user may see.
const signedOutPaths = {
  RoutePaths.welcome,
  RoutePaths.signIn,
  RoutePaths.verifyOtp,
  RoutePaths.legal,
};

/// Onboarding pages that a fully onboarded user is sent away from.
const onboardingPaths = {
  RoutePaths.splash,
  RoutePaths.welcome,
  RoutePaths.signIn,
  RoutePaths.verifyOtp,
  RoutePaths.ageGate,
  RoutePaths.createProfile,
  RoutePaths.communityRules,
  RoutePaths.permissions,
};

/// Pages an account locked by enforcement can still open.
const lockedOutPaths = {
  RoutePaths.enforcement,
  RoutePaths.legal,
  RoutePaths.helpSupport,
};

/// The onboarding flow (FL01) as a pure function, so it is testable:
///
/// unknown → splash; signed out → welcome (phone, OTP, legal allowed);
/// account not loaded or local prefs not read → splash; locked out →
/// account status; then the first unfinished step of age gate (A09) →
/// profile + gender (A08/A11) → community rules (A13) → permissions (A14)
/// → choose experience (A12). Legal pages stay reachable during onboarding.
/// Once complete, onboarding pages lead home (Discover, or Host Home in
/// host mode), and host-shell tabs are only for host mode.
String? onboardingRedirect({
  required SessionState session,
  required ExperienceController experience,
  required String location,
  required bool Function(String location) isHostShellLocation,
}) {
  // UI-preview only: `--dart-define=DASHURI_UI_PREVIEW=true` disables every
  // onboarding/session redirect so screens can be inspected without a login.
  if (const bool.fromEnvironment('DASHURI_UI_PREVIEW')) {
    return location == RoutePaths.splash ? RoutePaths.welcome : null;
  }
  switch (session) {
    case SessionUnknown():
      return location == RoutePaths.splash ? null : RoutePaths.splash;
    case SessionSignedOut():
      return signedOutPaths.contains(location) ? null : RoutePaths.welcome;
    case SessionSignedIn(:final account):
      if (account == null || !experience.isLoaded) {
        return location == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (account.isLockedOut) {
        return lockedOutPaths.contains(location)
            ? null
            : RoutePaths.enforcement;
      }
      final step = !account.ageEligible
          ? RoutePaths.ageGate
          : !account.profileComplete
          ? RoutePaths.createProfile
          : !account.rulesAccepted
          ? RoutePaths.communityRules
          : !experience.permissionsPrimerDone
          ? RoutePaths.permissions
          : experience.mode == null
          ? RoutePaths.chooseExperience
          : null;
      if (step != null) {
        return location == step || location == RoutePaths.legal ? null : step;
      }
      final host = experience.effectiveMode == ExperienceMode.host;
      if (onboardingPaths.contains(location)) {
        return host ? RoutePaths.hostDashboard : RoutePaths.discovery;
      }
      if (!host && isHostShellLocation(location)) return RoutePaths.discovery;
      return null;
  }
}

/// Wires [onboardingRedirect] to the live [SessionCubit] and
/// [ExperienceController]; notifies the router when either changes.
final class SessionRouteGuard extends ChangeNotifier implements RouteGuard {
  SessionRouteGuard(
    this._session,
    this._experience, {
    bool Function(String location)? isHostShellLocation,
  }) : _isHostShell = isHostShellLocation ?? ((_) => false) {
    _sessionSub = _session.stream.listen((_) => notifyListeners());
    _experienceSub = _experience.changes.listen((_) => notifyListeners());
  }

  final SessionCubit _session;
  final ExperienceController _experience;
  final bool Function(String location) _isHostShell;
  late final StreamSubscription<SessionState> _sessionSub;
  late final StreamSubscription<void> _experienceSub;

  @override
  String? redirect(GoRouterState state) => onboardingRedirect(
    session: _session.state,
    experience: _experience,
    location: state.matchedLocation,
    isHostShellLocation: _isHostShell,
  );

  @override
  void dispose() {
    unawaited(_sessionSub.cancel());
    unawaited(_experienceSub.cancel());
    super.dispose();
  }
}
