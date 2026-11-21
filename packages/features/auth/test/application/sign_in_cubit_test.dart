import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRequestOtp requestOtp;
  late MockVerifyOtp verifyOtp;

  setUpAll(() => registerFallbackValue((e164Phone: '', code: '')));
  setUp(() {
    requestOtp = MockRequestOtp();
    verifyOtp = MockVerifyOtp();
  });

  blocTest<SignInCubit, SignInState>(
    'sendCode normalises to E.164 and moves to awaitingCode',
    setUp: () => when(
      () => requestOtp(any()),
    ).thenAnswer((_) async => const Success<void>(null)),
    build: () => SignInCubit(requestOtp, verifyOtp),
    act: (c) => c.sendCode('98765 43210'),
    expect: () => const [
      SignInState(step: SignInStep.sendingCode, phone: '+919876543210'),
      SignInState(
        step: SignInStep.awaitingCode,
        phone: '+919876543210',
        codesSent: 1,
      ),
    ],
    verify: (_) => verify(() => requestOtp('+919876543210')).called(1),
  );

  blocTest<SignInCubit, SignInState>(
    'sendCode rejects an invalid number without calling the server',
    build: () => SignInCubit(requestOtp, verifyOtp),
    act: (c) => c.sendCode('12345'),
    expect: () => const [
      SignInState(
        failure: ValidationFailure(fieldErrors: {'phone': 'invalid_phone'}),
      ),
    ],
    verify: (_) => verifyNever(() => requestOtp(any())),
  );

  blocTest<SignInCubit, SignInState>(
    'sendCode returns to enterPhone on a rate limit',
    setUp: () => when(
      () => requestOtp(any()),
    ).thenAnswer((_) async => const Err<void>(RateLimitedFailure())),
    build: () => SignInCubit(requestOtp, verifyOtp),
    act: (c) => c.sendCode('9876543210'),
    skip: 1,
    expect: () => const [
      SignInState(phone: '+919876543210', failure: RateLimitedFailure()),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'verifyCode returns to awaitingCode with the failure on a wrong code',
    setUp: () => when(() => verifyOtp(any())).thenAnswer(
      (_) async =>
          const Err<AuthSession>(ValidationFailure(message: 'bad code')),
    ),
    build: () => SignInCubit(requestOtp, verifyOtp),
    seed: () => const SignInState(
      step: SignInStep.awaitingCode,
      phone: '+919876543210',
    ),
    act: (c) => c.verifyCode('000000'),
    expect: () => const [
      SignInState(step: SignInStep.verifying, phone: '+919876543210'),
      SignInState(
        step: SignInStep.awaitingCode,
        phone: '+919876543210',
        failure: ValidationFailure(message: 'bad code'),
      ),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'verifyCode succeeds',
    setUp: () =>
        when(() => verifyOtp(any())).thenAnswer((_) async => Success(session)),
    build: () => SignInCubit(requestOtp, verifyOtp),
    seed: () => const SignInState(
      step: SignInStep.awaitingCode,
      phone: '+919876543210',
    ),
    act: (c) => c.verifyCode('123456'),
    expect: () => const [
      SignInState(step: SignInStep.verifying, phone: '+919876543210'),
      SignInState(step: SignInStep.signedIn, phone: '+919876543210'),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'resume then resendCode increments codesSent',
    setUp: () => when(
      () => requestOtp(any()),
    ).thenAnswer((_) async => const Success<void>(null)),
    build: () => SignInCubit(requestOtp, verifyOtp),
    act: (c) async {
      c.resume('+919876543210');
      await c.resendCode();
    },
    expect: () => const [
      SignInState(
        step: SignInStep.awaitingCode,
        phone: '+919876543210',
        codesSent: 1,
      ),
      SignInState(
        step: SignInStep.sendingCode,
        phone: '+919876543210',
        codesSent: 1,
      ),
      SignInState(
        step: SignInStep.awaitingCode,
        phone: '+919876543210',
        codesSent: 2,
      ),
    ],
  );
}
