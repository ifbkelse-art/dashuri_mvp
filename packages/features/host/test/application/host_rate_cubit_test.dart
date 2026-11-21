import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockGetHostStatus getStatus;
  late MockSetRate setRate;
  const ready = HostRateState(
    status: HostRateStatus.ready,
    host: approvedOffline,
    rate: 2400,
  );

  setUpAll(registerHostFallbacks);
  setUp(() {
    getStatus = MockGetHostStatus();
    setRate = MockSetRate();
  });

  test('validate covers platform range and level cap', () {
    expect(
      HostRateCubit.validate(400, floor: 500, limit: 4000),
      RateError.belowMinimum,
    );
    expect(
      HostRateCubit.validate(10100, floor: 500, limit: 10000),
      RateError.abovePlatformMaximum,
    );
    expect(
      HostRateCubit.validate(4100, floor: 500, limit: 4000),
      RateError.aboveLevelLimit,
    );
    expect(HostRateCubit.validate(4000, floor: 500, limit: 4000), isNull);
    expect(BeanRules.beansPerMinute(2400), 1439);
  });

  blocTest<HostRateCubit, HostRateState>(
    'loads the current rate',
    setUp: () => when(
      () => getStatus(any()),
    ).thenAnswer((_) async => const Success(approvedOffline)),
    build: () => HostRateCubit(getStatus, setRate),
    act: (c) => c.load(),
    expect: () => const [HostRateState(), ready],
  );

  blocTest<HostRateCubit, HostRateState>(
    'stepper moves by 100 and flags the level cap',
    build: () => HostRateCubit(getStatus, setRate),
    seed: () => const HostRateState(
      status: HostRateStatus.ready,
      host: approvedOffline,
      rate: 4000,
    ),
    act: (c) => c
      ..increment()
      ..decrement(),
    expect: () => const [
      HostRateState(
        status: HostRateStatus.ready,
        host: approvedOffline,
        rate: 4100,
        error: RateError.aboveLevelLimit,
      ),
      HostRateState(
        status: HostRateStatus.ready,
        host: approvedOffline,
        rate: 4000,
      ),
    ],
  );

  blocTest<HostRateCubit, HostRateState>(
    'save is refused locally when the rate is invalid',
    build: () => HostRateCubit(getStatus, setRate),
    seed: () => const HostRateState(
      status: HostRateStatus.ready,
      host: approvedOffline,
      rate: 300,
    ),
    act: (c) => c.save(),
    expect: () => const [
      HostRateState(
        status: HostRateStatus.ready,
        host: approvedOffline,
        rate: 300,
        error: RateError.belowMinimum,
      ),
    ],
    verify: (_) => verifyNever(() => setRate(any())),
  );

  blocTest<HostRateCubit, HostRateState>(
    'save success',
    setUp: () => when(() => setRate(3000)).thenAnswer(
      (_) async => const Success(
        HostStatus(
          state: HostStates.approved,
          kycState: KycStates.approved,
          isAvailable: false,
          ratePerMinute: 3000,
          minRatePerMinute: 500,
          maxRatePerMinute: 4000,
          freeCallOptIn: true,
        ),
      ),
    ),
    build: () => HostRateCubit(getStatus, setRate),
    seed: () => const HostRateState(
      status: HostRateStatus.ready,
      host: approvedOffline,
      rate: 3000,
    ),
    act: (c) => c.save(),
    verify: (c) {
      expect(c.state.status, HostRateStatus.saved);
      expect(c.state.rate, 3000);
    },
  );

  blocTest<HostRateCubit, HostRateState>(
    'rate_outside_level_limits from the server maps to the level error',
    setUp: () => when(() => setRate(any())).thenAnswer(
      (_) async =>
          const Err(BusinessRuleFailure(code: 'rate_outside_level_limits')),
    ),
    build: () => HostRateCubit(getStatus, setRate),
    seed: () => ready,
    act: (c) => c.save(),
    expect: () => const [
      HostRateState(
        status: HostRateStatus.saving,
        host: approvedOffline,
        rate: 2400,
      ),
      HostRateState(
        status: HostRateStatus.ready,
        host: approvedOffline,
        rate: 2400,
        error: RateError.aboveLevelLimit,
        failure: BusinessRuleFailure(code: 'rate_outside_level_limits'),
      ),
    ],
  );

  blocTest<HostRateCubit, HostRateState>(
    'a 422 maps to the platform range error',
    setUp: () => when(() => setRate(any())).thenAnswer(
      (_) async => const Err(
        ValidationFailure(fieldErrors: {'rate_per_minute': 'above_maximum'}),
      ),
    ),
    build: () => HostRateCubit(getStatus, setRate),
    seed: () => ready,
    act: (c) => c.save(),
    verify: (c) => expect(c.state.error, RateError.abovePlatformMaximum),
  );
}
