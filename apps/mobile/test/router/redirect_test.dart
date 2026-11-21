import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_mobile/app/router/session_route_guard.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

String? redirect(
  SessionState session,
  String location, {
  FakeExperience? experience,
  bool hostShell = false,
}) => onboardingRedirect(
  session: session,
  experience: experience ?? FakeExperience(),
  location: location,
  isHostShellLocation: (_) => hostShell,
);

SessionSignedIn signedIn(AccountStatus? a, {Failure? failure}) =>
    SessionSignedIn(session: testSession, account: a, accountFailure: failure);

void main() {
  test('call route takes a callId parameter', () {
    expect(
      RoutePaths.withParams(RoutePaths.call, {'callId': 'c1'}),
      '/calls/c1',
    );
  });

  test('unknown session goes to splash', () {
    expect(
      redirect(const SessionUnknown(), RoutePaths.discovery),
      RoutePaths.splash,
    );
    expect(redirect(const SessionUnknown(), RoutePaths.splash), isNull);
  });

  group('signed out', () {
    test('welcome, phone, OTP and legal are allowed', () {
      for (final p in [
        RoutePaths.welcome,
        RoutePaths.signIn,
        RoutePaths.verifyOtp,
        RoutePaths.legal,
      ]) {
        expect(redirect(const SessionSignedOut(), p), isNull, reason: p);
      }
    });

    test('everything else goes to welcome', () {
      for (final p in [
        RoutePaths.splash,
        RoutePaths.discovery,
        RoutePaths.ageGate,
      ]) {
        expect(
          redirect(const SessionSignedOut(), p),
          RoutePaths.welcome,
          reason: p,
        );
      }
    });
  });

  group('signed in', () {
    test('account not loaded (error) stays on splash', () {
      final s = signedIn(null, failure: const NetworkFailure());
      expect(redirect(s, RoutePaths.discovery), RoutePaths.splash);
      expect(redirect(s, RoutePaths.splash), isNull);
    });

    test('local preferences not read yet stays on splash', () {
      expect(
        redirect(
          signedIn(accountWith()),
          RoutePaths.discovery,
          experience: FakeExperience(isLoaded: false),
        ),
        RoutePaths.splash,
      );
    });

    test('not 18+ → age gate (legal still reachable)', () {
      final s = signedIn(accountWith(age: false, profile: false, rules: false));
      expect(redirect(s, RoutePaths.discovery), RoutePaths.ageGate);
      expect(redirect(s, RoutePaths.verifyOtp), RoutePaths.ageGate);
      expect(redirect(s, RoutePaths.ageGate), isNull);
      expect(redirect(s, RoutePaths.legal), isNull);
    });

    test('profile incomplete → create profile', () {
      final s = signedIn(accountWith(profile: false, rules: false));
      expect(redirect(s, RoutePaths.ageGate), RoutePaths.createProfile);
      expect(redirect(s, RoutePaths.createProfile), isNull);
    });

    test('rules not accepted → community rules', () {
      final s = signedIn(accountWith(rules: false));
      expect(redirect(s, RoutePaths.createProfile), RoutePaths.communityRules);
      expect(redirect(s, RoutePaths.communityRules), isNull);
    });

    test('permissions primer not done → permissions', () {
      final s = signedIn(accountWith());
      final e = FakeExperience(permissionsPrimerDone: false, mode: null);
      expect(
        redirect(s, RoutePaths.discovery, experience: e),
        RoutePaths.permissions,
      );
      expect(redirect(s, RoutePaths.permissions, experience: e), isNull);
    });

    test('no experience chosen → choose experience', () {
      final s = signedIn(accountWith());
      final e = FakeExperience(mode: null);
      expect(
        redirect(s, RoutePaths.permissions, experience: e),
        RoutePaths.chooseExperience,
      );
      expect(redirect(s, RoutePaths.chooseExperience, experience: e), isNull);
    });

    test('complete customer: onboarding pages lead to Discover', () {
      final s = signedIn(accountWith());
      for (final p in [
        RoutePaths.splash,
        RoutePaths.welcome,
        RoutePaths.verifyOtp,
        RoutePaths.ageGate,
        RoutePaths.communityRules,
      ]) {
        expect(redirect(s, p), RoutePaths.discovery, reason: p);
      }
      expect(redirect(s, RoutePaths.wallet), isNull);
      expect(redirect(s, RoutePaths.chooseExperience), isNull);
      expect(redirect(s, RoutePaths.hostOnboarding), isNull);
    });

    test('customer mode cannot open host-shell tabs', () {
      expect(
        redirect(
          signedIn(accountWith()),
          RoutePaths.hostCalls,
          hostShell: true,
        ),
        RoutePaths.discovery,
      );
    });

    test('approved host in host mode goes to Host Home', () {
      final s = signedIn(accountWith(host: true));
      final e = FakeExperience(
        mode: ExperienceMode.host,
        hostModeAvailable: true,
      );
      expect(
        redirect(s, RoutePaths.splash, experience: e),
        RoutePaths.hostDashboard,
      );
      expect(
        redirect(s, RoutePaths.hostCalls, experience: e, hostShell: true),
        isNull,
      );
    });

    test('host intent without approval stays in the customer shell', () {
      final s = signedIn(accountWith());
      final e = FakeExperience(mode: ExperienceMode.host);
      expect(
        redirect(s, RoutePaths.splash, experience: e),
        RoutePaths.discovery,
      );
    });

    test('suspended account is locked to account status', () {
      final s = signedIn(accountWith(restriction: 'suspended'));
      expect(redirect(s, RoutePaths.discovery), RoutePaths.enforcement);
      expect(redirect(s, RoutePaths.enforcement), isNull);
      expect(redirect(s, RoutePaths.helpSupport), isNull);
    });
  });
}
