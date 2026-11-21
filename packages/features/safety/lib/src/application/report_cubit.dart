import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/report_category.dart';
import '../domain/usecases/block_user.dart';
import '../domain/usecases/report_user.dart';

/// V11 report form and V12 confirmation. One idempotency key per report
/// intent (and one per block), reused on retries.
final class ReportCubit extends Cubit<ReportState> {
  ReportCubit(
    this._report,
    this._block, {
    required String targetUserId,
    String? callId,
  }) : _target = targetUserId,
       _callId = callId,
       super(const ReportState());

  final ReportUser _report;
  final BlockUser _block;
  final String _target;
  final String? _callId;
  final IdempotencyKey _reportKey = IdempotencyKey.generate();
  final IdempotencyKey _blockKey = IdempotencyKey.generate();
  bool _reported = false;

  void selectCategory(ReportCategory c) =>
      emit(state.copyWith(category: c, clearFailure: true));

  void setDetails(String details) => emit(state.copyWith(details: details));

  void setAlsoBlock(bool value) => emit(state.copyWith(alsoBlock: value));

  Future<void> submit() async {
    final category = state.category;
    if (category == null || state.submitting) return;
    if (state.details.length > reportDetailsMaxLength) return;
    emit(state.copyWith(submitting: true, clearFailure: true));
    if (!_reported) {
      final details = state.details.trim();
      final result = await _report((
        targetUserId: _target,
        category: category.wire,
        callId: _callId,
        details: details.isEmpty ? null : details,
        idempotencyKey: _reportKey,
      ));
      if (result case Err(:final failure)) {
        emit(state.copyWith(submitting: false, failure: failure));
        return;
      }
      _reported = true;
    }
    var blocked = false;
    Failure? blockFailure;
    if (state.alsoBlock) {
      final result = await _block((userId: _target, idempotencyKey: _blockKey));
      switch (result) {
        case Success():
          blocked = true;
        // Already blocked counts as blocked.
        case Err(failure: ConflictFailure() || BusinessRuleFailure()):
          blocked = true;
        case Err(:final failure):
          blockFailure = failure;
      }
    }
    emit(
      state.copyWith(
        submitting: false,
        submitted: true,
        blocked: blocked,
        failure: blockFailure,
      ),
    );
  }
}

final class ReportState extends Equatable {
  const ReportState({
    this.category,
    this.details = '',
    this.alsoBlock = true,
    this.submitting = false,
    this.submitted = false,
    this.blocked = false,
    this.failure,
  });

  final ReportCategory? category;
  final String details;

  /// V11: "Also block" is pre-checked.
  final bool alsoBlock;
  final bool submitting;
  final bool submitted;
  final bool blocked;

  /// Report failure (before submission) or block failure (after).
  final Failure? failure;

  bool get canSubmit =>
      category != null &&
      !submitting &&
      details.length <= reportDetailsMaxLength;

  ReportState copyWith({
    ReportCategory? category,
    String? details,
    bool? alsoBlock,
    bool? submitting,
    bool? submitted,
    bool? blocked,
    Failure? failure,
    bool clearFailure = false,
  }) => ReportState(
    category: category ?? this.category,
    details: details ?? this.details,
    alsoBlock: alsoBlock ?? this.alsoBlock,
    submitting: submitting ?? this.submitting,
    submitted: submitted ?? this.submitted,
    blocked: blocked ?? this.blocked,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [
    category,
    details,
    alsoBlock,
    submitting,
    submitted,
    blocked,
    failure,
  ];
}
