import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockGetHostStatus getStatus;
  late MockApplyAsHost apply;

  setUpAll(registerHostFallbacks);
  setUp(() {
    getStatus = MockGetHostStatus();
    apply = MockApplyAsHost();
  });

  group('nextApplicationStep', () {
    test('maps every status to the flow step', () {
      expect(
        nextApplicationStep(HostStatus.notApplied),
        HostApplicationStep.apply,
      );
      expect(nextApplicationStep(appliedHost), HostApplicationStep.agreement);
      expect(nextApplicationStep(kycPendingHost), HostApplicationStep.review);
      expect(
        nextApplicationStep(kycRejectedHost),
        HostApplicationStep.attention,
      );
      expect(
        nextApplicationStep(approvedOffline),
        HostApplicationStep.approved,
      );
      expect(
        nextApplicationStep(
          const HostStatus(
            state: HostStates.suspended,
            kycState: KycStates.approved,
            isAvailable: false,
            ratePerMinute: 500,
            minRatePerMinute: 500,
            maxRatePerMinute: 500,
            freeCallOptIn: false,
          ),
        ),
        HostApplicationStep.suspended,
      );
    });
  });

  blocTest<HostApplicationCubit, HostApplicationState>(
    'load: not applied',
    setUp: () => when(
      () => getStatus(any()),
    ).thenAnswer((_) async => const Success(HostStatus.notApplied)),
    build: () => HostApplicationCubit(getStatus, apply),
    act: (c) => c.load(),
    expect: () => const [
      HostApplicationState(),
      HostApplicationState(
        status: HostApplicationStatus.ready,
        host: HostStatus.notApplied,
      ),
    ],
  );

  blocTest<HostApplicationCubit, HostApplicationState>(
    'load failure',
    setUp: () => when(
      () => getStatus(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => HostApplicationCubit(getStatus, apply),
    act: (c) => c.load(),
    expect: () => const [
      HostApplicationState(),
      HostApplicationState(
        status: HostApplicationStatus.loadFailed,
        failure: NetworkFailure(),
      ),
    ],
  );

  blocTest<HostApplicationCubit, HostApplicationState>(
    'apply success moves on to the agreement',
    setUp: () => when(
      () => apply(any()),
    ).thenAnswer((_) async => const Success(appliedHost)),
    build: () => HostApplicationCubit(getStatus, apply),
    seed: () => const HostApplicationState(
      status: HostApplicationStatus.ready,
      host: HostStatus.notApplied,
    ),
    act: (c) => c.apply(),
    expect: () => const [
      HostApplicationState(
        status: HostApplicationStatus.submitting,
        host: HostStatus.notApplied,
      ),
      HostApplicationState(
        status: HostApplicationStatus.ready,
        host: appliedHost,
        appliedNow: true,
      ),
    ],
    verify: (c) => expect(c.state.nextStep, HostApplicationStep.agreement),
  );

  blocTest<HostApplicationCubit, HostApplicationState>(
    'apply retry after a network error reuses the idempotency key',
    setUp: () {
      var calls = 0;
      when(() => apply(any())).thenAnswer(
        (_) async => calls++ == 0
            ? const Err(NetworkFailure())
            : const Success(appliedHost),
      );
    },
    build: () => HostApplicationCubit(getStatus, apply),
    seed: () => const HostApplicationState(
      status: HostApplicationStatus.ready,
      host: HostStatus.notApplied,
    ),
    act: (c) async {
      await c.apply();
      await c.apply();
    },
    verify: (c) {
      final keys = verify(() => apply(captureAny())).captured;
      expect(keys, hasLength(2));
      expect(
        (keys[0] as IdempotencyKey).value,
        (keys[1] as IdempotencyKey).value,
      );
      expect(c.state.appliedNow, isTrue);
    },
  );

  blocTest<HostApplicationCubit, HostApplicationState>(
    'already_applied re-reads status and continues',
    setUp: () {
      when(() => apply(any())).thenAnswer(
        (_) async => const Err(BusinessRuleFailure(code: 'already_applied')),
      );
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(kycPendingHost));
    },
    build: () => HostApplicationCubit(getStatus, apply),
    seed: () => const HostApplicationState(status: HostApplicationStatus.ready),
    act: (c) => c.apply(),
    expect: () => const [
      HostApplicationState(status: HostApplicationStatus.submitting),
      HostApplicationState(
        status: HostApplicationStatus.ready,
        host: kycPendingHost,
        appliedNow: true,
      ),
    ],
  );

  blocTest<HostApplicationCubit, HostApplicationState>(
    'not_age_eligible is reported without moving on',
    setUp: () => when(() => apply(any())).thenAnswer(
      (_) async => const Err(BusinessRuleFailure(code: 'not_age_eligible')),
    ),
    build: () => HostApplicationCubit(getStatus, apply),
    seed: () => const HostApplicationState(
      status: HostApplicationStatus.ready,
      host: HostStatus.notApplied,
    ),
    act: (c) => c.apply(),
    skip: 1,
    expect: () => const [
      HostApplicationState(
        status: HostApplicationStatus.ready,
        host: HostStatus.notApplied,
        failure: BusinessRuleFailure(code: 'not_age_eligible'),
      ),
    ],
  );
}
