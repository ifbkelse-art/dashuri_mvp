import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/age.dart';
import '../domain/usecases/submit_age_declaration.dart';

/// A09 age declaration and A10 blocked state.
final class AgeGateCubit extends Cubit<AgeGateState> {
  AgeGateCubit(this._submit, this._refresher, this._clock)
    : super(const AgeGateState());

  final SubmitAgeDeclaration _submit;
  final AccountStatusRefresher _refresher;
  final Clock _clock;
  IdempotencyKey? _key;
  String? _keyFor;

  void setDateOfBirth(DateTime dob) => emit(
    state.copyWith(
      dateOfBirth: dob,
      age: ageOn(dob, _clock.now()),
      clearFailure: true,
    ),
  );

  void setConfirmed(bool value) => emit(state.copyWith(confirmed: value));

  bool get canSubmit =>
      state.dateOfBirth != null && state.confirmed && !state.submitting;

  /// Declares the DOB. Under-18 dates are also sent so the server records
  /// them; the page then shows the blocked state (no "edit date" back door).
  Future<void> submit() async {
    final dob = state.dateOfBirth;
    if (dob == null || !state.confirmed || state.submitting) return;
    final iso = isoDate(dob);
    if (_keyFor != iso) {
      _key = IdempotencyKey.generate();
      _keyFor = iso;
    }
    emit(state.copyWith(submitting: true, clearFailure: true));
    final result = await _submit((dateOfBirth: iso, idempotencyKey: _key!));
    switch (result) {
      case Success(:final value) when value.eligible:
        await _refresher.refreshAccountStatus();
        emit(
          state.copyWith(submitting: false, outcome: AgeGateOutcome.eligible),
        );
      case Success():
        emit(
          state.copyWith(submitting: false, outcome: AgeGateOutcome.blocked),
        );
      case Err(failure: BusinessRuleFailure() || ConflictFailure()):
        // The server refuses a re-declaration after an under-18 answer.
        emit(
          state.copyWith(submitting: false, outcome: AgeGateOutcome.blocked),
        );
      case Err(:final failure):
        emit(state.copyWith(submitting: false, failure: failure));
    }
  }
}

enum AgeGateOutcome { pending, eligible, blocked }

final class AgeGateState extends Equatable {
  const AgeGateState({
    this.dateOfBirth,
    this.age,
    this.confirmed = false,
    this.submitting = false,
    this.outcome = AgeGateOutcome.pending,
    this.failure,
  });

  final DateTime? dateOfBirth;
  final int? age;
  final bool confirmed;
  final bool submitting;
  final AgeGateOutcome outcome;
  final Failure? failure;

  AgeGateState copyWith({
    DateTime? dateOfBirth,
    int? age,
    bool? confirmed,
    bool? submitting,
    AgeGateOutcome? outcome,
    Failure? failure,
    bool clearFailure = false,
  }) => AgeGateState(
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    age: age ?? this.age,
    confirmed: confirmed ?? this.confirmed,
    submitting: submitting ?? this.submitting,
    outcome: outcome ?? this.outcome,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [
    dateOfBirth,
    age,
    confirmed,
    submitting,
    outcome,
    failure,
  ];
}
