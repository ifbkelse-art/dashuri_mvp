import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRequestOtp extends Mock implements RequestOtp {}

class _MockVerifyOtp extends Mock implements VerifyOtp {}

void main() {
  late _MockRequestOtp requestOtp;
  late _MockVerifyOtp verifyOtp;

  setUpAll(() => registerFallbackValue((e164Phone: '', code: '')));
  setUp(() {
    requestOtp = _MockRequestOtp();
    verifyOtp = _MockVerifyOtp();
  });

  blocTest<SignInCubit, SignInState>(
    'sendCode moves to awaitingCode on success',
    setUp: () => when(
      () => requestOtp(any()),
    ).thenAnswer((_) async => const Success<void>(null)),
    build: () => SignInCubit(requestOtp, verifyOtp),
    act: (c) => c.sendCode('+919876543210'),
    expect: () => const [
      SignInState(step: SignInStep.sendingCode, phone: '+919876543210'),
      SignInState(step: SignInStep.awaitingCode, phone: '+919876543210'),
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
}
