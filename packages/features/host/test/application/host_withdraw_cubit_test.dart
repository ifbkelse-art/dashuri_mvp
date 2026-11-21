import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockGetEarnings getEarnings;
  late MockRequestWithdrawal request;

  HostWithdrawCubit build() => HostWithdrawCubit(getEarnings, request);
  HostWithdrawState editing([int? beans]) => HostWithdrawState(
    phase: WithdrawPhase.editing,
    earnings: sampleEarnings,
    beans: beans ?? sampleEarnings.beansAvailable,
  );

  setUpAll(registerHostFallbacks);
  setUp(() {
    getEarnings = MockGetEarnings();
    request = MockRequestWithdrawal();
    when(
      () => getEarnings(any()),
    ).thenAnswer((_) async => Success(sampleEarnings));
  });

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'load defaults to the full withdrawable balance',
    build: build,
    act: (c) => c.load(),
    expect: () => [const HostWithdrawState(), editing()],
    verify: (c) => expect(c.state.amountPaise, 62150),
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'load below the minimum shows H25',
    setUp: () => when(
      () => getEarnings(any()),
    ).thenAnswer((_) async => const Success(lowEarnings)),
    build: build,
    act: (c) => c.load(),
    verify: (c) => expect(c.state.phase, WithdrawPhase.belowMinimum),
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'amount validation: below minimum and above available',
    build: build,
    seed: editing,
    act: (c) => c
      ..setBeans(99999)
      ..setBeans(200000)
      ..setBeans(100000),
    expect: () => [
      HostWithdrawState(
        phase: WithdrawPhase.editing,
        earnings: sampleEarnings,
        beans: 99999,
        amountError: WithdrawAmountError.belowMinimum,
      ),
      HostWithdrawState(
        phase: WithdrawPhase.editing,
        earnings: sampleEarnings,
        beans: 200000,
        amountError: WithdrawAmountError.aboveAvailable,
      ),
      editing(100000),
    ],
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'success shows the requested state (H18)',
    setUp: () => when(
      () => request(any()),
    ).thenAnswer((_) async => Success(sampleWithdrawal)),
    build: build,
    seed: editing,
    act: (c) => c.submit(),
    expect: () => [
      HostWithdrawState(
        phase: WithdrawPhase.submitting,
        earnings: sampleEarnings,
        beans: 124300,
      ),
      HostWithdrawState(
        phase: WithdrawPhase.requested,
        earnings: sampleEarnings,
        beans: 124300,
        withdrawal: sampleWithdrawal,
      ),
    ],
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'payouts_not_enabled (503) shows H21',
    setUp: () => when(() => request(any())).thenAnswer(
      (_) async => const Err(ServerFailure(code: 'payouts_not_enabled')),
    ),
    build: build,
    seed: editing,
    act: (c) => c.submit(),
    verify: (c) => expect(c.state.phase, WithdrawPhase.payoutsDisabled),
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'below_minimum_withdrawal from the server shows H25',
    setUp: () => when(() => request(any())).thenAnswer(
      (_) async =>
          const Err(BusinessRuleFailure(code: 'below_minimum_withdrawal')),
    ),
    build: build,
    seed: editing,
    act: (c) => c.submit(),
    verify: (c) => expect(c.state.phase, WithdrawPhase.belowMinimum),
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'insufficient_available_beans refreshes the balance and reports it',
    setUp: () {
      when(() => request(any())).thenAnswer(
        (_) async => const Err(
          BusinessRuleFailure(code: 'insufficient_available_beans'),
        ),
      );
      when(
        () => getEarnings(any()),
      ).thenAnswer((_) async => const Success(lowEarnings));
    },
    build: build,
    seed: editing,
    act: (c) => c.submit(),
    verify: (c) {
      expect(c.state.phase, WithdrawPhase.belowMinimum);
      expect(c.state.earnings, lowEarnings);
      expect(c.state.failure?.code, 'insufficient_available_beans');
    },
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'a network failure keeps the same idempotency key for the retry',
    setUp: () {
      var n = 0;
      when(() => request(any())).thenAnswer(
        (_) async =>
            n++ == 0 ? const Err(NetworkFailure()) : Success(sampleWithdrawal),
      );
    },
    build: build,
    seed: editing,
    act: (c) async {
      await c.submit();
      expect(c.state.phase, WithdrawPhase.editing);
      expect(c.state.failure, const NetworkFailure());
      await c.submit();
    },
    verify: (c) {
      final inputs = verify(
        () => request(captureAny()),
      ).captured.cast<({int beans, IdempotencyKey idempotencyKey})>();
      expect(inputs[0].idempotencyKey.value, inputs[1].idempotencyKey.value);
      expect(c.state.phase, WithdrawPhase.requested);
    },
  );

  blocTest<HostWithdrawCubit, HostWithdrawState>(
    'invalid amount is not submitted',
    build: build,
    seed: () => editing(50000),
    act: (c) => c.submit(),
    verify: (c) {
      verifyNever(() => request(any()));
      expect(c.state.amountError, WithdrawAmountError.belowMinimum);
    },
  );
}
