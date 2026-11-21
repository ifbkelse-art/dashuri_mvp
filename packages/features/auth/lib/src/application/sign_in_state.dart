part of 'sign_in_cubit.dart';

enum SignInStep { enterPhone, sendingCode, awaitingCode, verifying, signedIn }

final class SignInState extends Equatable {
  const SignInState({
    this.step = SignInStep.enterPhone,
    this.phone = '',
    this.failure,
  });

  final SignInStep step;
  final String phone;
  final Failure? failure;

  SignInState copyWith({SignInStep? step, String? phone, Failure? failure}) =>
      SignInState(
        step: step ?? this.step,
        phone: phone ?? this.phone,
        failure: failure,
      );

  @override
  List<Object?> get props => [step, phone, failure];
}
