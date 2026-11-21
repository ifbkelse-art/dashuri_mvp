part of 'sign_in_cubit.dart';

enum SignInStep { enterPhone, sendingCode, awaitingCode, verifying, signedIn }

final class SignInState extends Equatable {
  const SignInState({
    this.step = SignInStep.enterPhone,
    this.phone = '',
    this.failure,
    this.codesSent = 0,
  });

  final SignInStep step;

  /// E.164 phone number the code was (or will be) sent to.
  final String phone;
  final Failure? failure;

  /// Incremented on every successful send/resend; the OTP page restarts its
  /// resend countdown when this changes.
  final int codesSent;

  SignInState copyWith({
    SignInStep? step,
    String? phone,
    Failure? failure,
    int? codesSent,
  }) => SignInState(
    step: step ?? this.step,
    phone: phone ?? this.phone,
    failure: failure,
    codesSent: codesSent ?? this.codesSent,
  );

  @override
  List<Object?> get props => [step, phone, failure, codesSent];
}
