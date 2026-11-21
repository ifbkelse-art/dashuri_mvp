import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/usecases/request_otp.dart';
import '../domain/usecases/verify_otp.dart';

part 'sign_in_state.dart';

/// Phone OTP flow for the sign-in page.
final class SignInCubit extends Cubit<SignInState> {
  SignInCubit(this._requestOtp, this._verifyOtp) : super(const SignInState());

  final RequestOtp _requestOtp;
  final VerifyOtp _verifyOtp;

  /// [e164Phone] e.g. +919876543210. Formatting/validation UI is the page's job.
  Future<void> sendCode(String e164Phone) async {
    emit(
      state.copyWith(
        step: SignInStep.sendingCode,
        phone: e164Phone,
        failure: null,
      ),
    );
    final result = await _requestOtp(e164Phone);
    emit(switch (result) {
      Success() => state.copyWith(step: SignInStep.awaitingCode),
      Err(:final failure) => state.copyWith(
        step: SignInStep.enterPhone,
        failure: failure,
      ),
    });
  }

  Future<void> verifyCode(String code) async {
    emit(state.copyWith(step: SignInStep.verifying, failure: null));
    final result = await _verifyOtp((e164Phone: state.phone, code: code));
    emit(switch (result) {
      Success() => state.copyWith(step: SignInStep.signedIn),
      Err(:final failure) => state.copyWith(
        step: SignInStep.awaitingCode,
        failure: failure,
      ),
    });
  }
}
