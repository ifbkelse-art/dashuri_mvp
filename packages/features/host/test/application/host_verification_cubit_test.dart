import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockGetHostStatus getStatus;
  late MockStartKyc startKyc;
  const session = KycSession(sessionId: 'kyc_1', redirectUrl: null);

  setUpAll(registerHostFallbacks);
  setUp(() {
    getStatus = MockGetHostStatus();
    startKyc = MockStartKyc();
  });

  blocTest<HostVerificationCubit, HostVerificationState>(
    'load shows the review step for a KYC in progress',
    setUp: () => when(
      () => getStatus(any()),
    ).thenAnswer((_) async => const Success(kycPendingHost)),
    build: () => HostVerificationCubit(getStatus, startKyc),
    act: (c) => c.load(),
    expect: () => const [
      HostVerificationState(),
      HostVerificationState(
        status: HostVerificationStatus.ready,
        host: kycPendingHost,
      ),
    ],
    verify: (c) => expect(c.state.step, HostApplicationStep.review),
  );

  blocTest<HostVerificationCubit, HostVerificationState>(
    'starting a manual KYC session re-reads status and signals navigation',
    setUp: () {
      when(
        () => startKyc(any()),
      ).thenAnswer((_) async => const Success(session));
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(kycPendingHost));
    },
    build: () => HostVerificationCubit(getStatus, startKyc),
    seed: () => const HostVerificationState(
      status: HostVerificationStatus.ready,
      host: appliedHost,
    ),
    act: (c) => c.startVerification(),
    expect: () => const [
      HostVerificationState(
        status: HostVerificationStatus.starting,
        host: appliedHost,
      ),
      HostVerificationState(
        status: HostVerificationStatus.ready,
        host: kycPendingHost,
        session: session,
        sessionStartedNow: true,
      ),
    ],
  );

  blocTest<HostVerificationCubit, HostVerificationState>(
    'a failed start keeps the key for retry and reports the failure',
    setUp: () => when(
      () => startKyc(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => HostVerificationCubit(getStatus, startKyc),
    seed: () => const HostVerificationState(
      status: HostVerificationStatus.ready,
      host: kycRejectedHost,
    ),
    act: (c) async {
      await c.startVerification();
      await c.startVerification();
    },
    verify: (c) {
      final keys = verify(() => startKyc(captureAny())).captured;
      expect(
        (keys[0] as IdempotencyKey).value,
        (keys[1] as IdempotencyKey).value,
      );
      expect(c.state.failure, const NetworkFailure());
      expect(c.state.step, HostApplicationStep.attention);
    },
  );

  blocTest<HostVerificationCubit, HostVerificationState>(
    'kyc_not_required reloads the status',
    setUp: () {
      when(() => startKyc(any())).thenAnswer(
        (_) async => const Err(BusinessRuleFailure(code: 'kyc_not_required')),
      );
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
    },
    build: () => HostVerificationCubit(getStatus, startKyc),
    seed: () => const HostVerificationState(
      status: HostVerificationStatus.ready,
      host: appliedHost,
    ),
    act: (c) => c.startVerification(),
    verify: (c) => expect(c.state.step, HostApplicationStep.approved),
  );
}
