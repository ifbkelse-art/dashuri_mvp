import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/phone_number.dart';
import '../domain/usecases/request_otp.dart';
import '../domain/usecases/verify_otp.dart';

part 'sign_in_state.dart';

/// Phone OTP flow (A03–A06). Phone OTP is the only method (D-02).
class SignInCubit extends Cubit<SignInState> {
  SignInCubit(this._requestOtp, this._verifyOtp) : super(const SignInState());

  final RequestOtp _requestOtp;
  final VerifyOtp _verifyOtp;

  /// Sends a code to [phoneInput] (10 digits or +91…). Invalid Indian
  /// numbers fail locally with `invalid_phone` and never reach the server.
  Future<void> sendCode(String phoneInput) async {
    final e164 = IndianPhoneNumber.toE164(phoneInput);
    if (e164 == null) {
      emit(
        state.copyWith(
          step: SignInStep.enterPhone,
          failure: const ValidationFailure(
            fieldErrors: {'phone': 'invalid_phone'},
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(step: SignInStep.sendingCode, phone: e164, failure: null),
    );
    final result = await _requestOtp(e164);
    emit(switch (result) {
      Success() => state.copyWith(
        step: SignInStep.awaitingCode,
        codesSent: state.codesSent + 1,
      ),
      Err(:final failure) => state.copyWith(
        step: SignInStep.enterPhone,
        failure: failure,
      ),
    });
  }

  /// Continues on the OTP page for a code already sent to [e164Phone].
  void resume(String e164Phone) => emit(
    SignInState(step: SignInStep.awaitingCode, phone: e164Phone, codesSent: 1),
  );

  Future<void> resendCode() async {
    emit(state.copyWith(step: SignInStep.sendingCode, failure: null));
    final result = await _requestOtp(state.phone);
    emit(switch (result) {
      Success() => state.copyWith(
        step: SignInStep.awaitingCode,
        codesSent: state.codesSent + 1,
      ),
      Err(:final failure) => state.copyWith(
        step: SignInStep.awaitingCode,
        failure: failure,
      ),
    });
  }

  Future<void> verifyCode(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      emit(
        state.copyWith(
          step: SignInStep.awaitingCode,
          failure: const ValidationFailure(fieldErrors: {'code': 'invalid'}),
        ),
      );
      return;
    }
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
