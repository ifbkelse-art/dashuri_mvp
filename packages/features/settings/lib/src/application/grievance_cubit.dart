import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/usecases/settings_usecases.dart';

/// S07 grievance form (D-22): a report of category `other`.
class GrievanceCubit extends Cubit<GrievanceState> {
  GrievanceCubit(this._submit) : super(const GrievanceState());

  final SubmitGrievance _submit;
  final IdempotencyKey _key = IdempotencyKey.generate();

  void changed(String text) =>
      emit(GrievanceState(text: text, submitted: state.submitted));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(GrievanceState(text: state.text, submitting: true));
    final result = await _submit((
      details: state.text.trim(),
      idempotencyKey: _key,
    ));
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => GrievanceState(
        submitted: true,
        referenceId: value,
      ),
      Err(:final failure) => GrievanceState(text: state.text, failure: failure),
    });
  }
}

final class GrievanceState extends Equatable {
  const GrievanceState({
    this.text = '',
    this.submitting = false,
    this.submitted = false,
    this.referenceId,
    this.failure,
  });

  final String text;
  final bool submitting;
  final bool submitted;
  final String? referenceId;
  final Failure? failure;

  bool get canSubmit =>
      text.trim().length >= 10 &&
      text.length <= grievanceMaxLength &&
      !submitting &&
      !submitted;

  @override
  List<Object?> get props => [
    text,
    submitting,
    submitted,
    referenceId,
    failure,
  ];
}
