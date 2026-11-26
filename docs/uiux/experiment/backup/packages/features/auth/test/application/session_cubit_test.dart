import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  late MockWatchSession watch;
  late MockGetAccountStatus getAccount;
  late StreamController<AuthSession?> sessions;

  setUpAll(() => registerFallbackValue(const NoInput()));
  setUp(() {
    watch = MockWatchSession();
    getAccount = MockGetAccountStatus();
    sessions = StreamController<AuthSession?>.broadcast();
    when(() => watch(any())).thenAnswer((_) => sessions.stream);
  });
  tearDown(() => sessions.close());

  blocTest<SessionCubit, SessionState>(
    'signed out, then signed in with the account status',
    setUp: () => when(
      () => getAccount(any()),
    ).thenAnswer((_) async => const Success(account)),
    build: () => SessionCubit(watch, getAccount),
    act: (c) async {
      c.start();
      sessions
        ..add(null)
        ..add(session);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const SessionSignedOut(),
      SessionSignedIn(session: session, account: account),
    ],
  );

  blocTest<SessionCubit, SessionState>(
    'keeps the failure when GET /v1/me fails, and refreshAccount retries',
    setUp: () {
      var calls = 0;
      when(() => getAccount(any())).thenAnswer(
        (_) async =>
            calls++ == 0 ? const Err(NetworkFailure()) : const Success(account),
      );
    },
    build: () => SessionCubit(watch, getAccount),
    act: (c) async {
      c.start();
      sessions.add(session);
      await Future<void>.delayed(Duration.zero);
      await c.refreshAccountStatus();
    },
    expect: () => [
      SessionSignedIn(
        session: session,
        account: null,
        accountFailure: const NetworkFailure(),
      ),
      SessionSignedIn(session: session, account: account),
    ],
  );

  blocTest<SessionCubit, SessionState>(
    'applyAccount replaces the account without a round trip',
    build: () => SessionCubit(watch, getAccount),
    seed: () => SessionSignedIn(session: session, account: null),
    act: (c) => c.applyAccount(account),
    expect: () => [SessionSignedIn(session: session, account: account)],
    verify: (_) => verifyNever(() => getAccount(any())),
  );

  test('SessionSignedIn getters read the account', () {
    final s = SessionSignedIn(session: session, account: account);
    expect(s.ageEligible && s.profileComplete && s.rulesAccepted, isTrue);
    expect(s.isApprovedHost, isFalse);
    expect(
      SessionSignedIn(session: session, account: null).ageEligible,
      isFalse,
    );
  });
}
