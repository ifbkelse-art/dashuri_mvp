import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_mobile/app/purchases/purchase_recovery_binding.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  // Regression (2026-11-27): unfinished Play purchases were recovered only
  // when the purchase screen opened. Now: on sign-in and on every resume.
  test('runs once per signed-in user and on every resume', () async {
    var runs = 0;
    final b = PurchaseRecoveryBinding(() async => ++runs);
    final changes = StreamController<SessionState>();
    b.bind(changes.stream, const SessionUnknown());
    expect(runs, 0, reason: 'not signed in yet');

    final signedIn = SessionSignedIn(
      session: testSession,
      account: accountWith(),
    );
    changes.add(signedIn);
    await Future<void>.delayed(Duration.zero);
    expect(runs, 1);

    // Account refreshes for the same user do not re-run it.
    changes.add(signedIn);
    await Future<void>.delayed(Duration.zero);
    expect(runs, 1);

    b.onResume();
    expect(runs, 2);

    changes.add(const SessionSignedOut());
    await Future<void>.delayed(Duration.zero);
    b.onResume();
    expect(runs, 2, reason: 'signed out: nothing to recover');

    changes.add(
      SessionSignedIn(
        session: AuthSession(userId: 'u2', expiresAt: DateTime.utc(2030)),
        account: accountWith(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(runs, 3, reason: 'a different user signs in');

    await b.dispose();
    await changes.close();
  });

  test('a failing recovery never throws', () async {
    final b = PurchaseRecoveryBinding(
      () async => throw Exception('offline'),
    )..onSession(SessionSignedIn(session: testSession, account: accountWith()));
    await Future<void>.delayed(Duration.zero);
    b.onResume();
    await Future<void>.delayed(Duration.zero);
  });
}
