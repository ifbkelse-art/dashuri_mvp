import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/enforcement_notice.dart';
import '../domain/entities/report_category.dart';
import '../domain/usecases/list_enforcement_notices.dart';
import '../domain/usecases/submit_appeal.dart';

/// Enforcement notices (GET /v1/me/enforcement) and appeals (POST /v1/appeals).
final class EnforcementCubit extends Cubit<EnforcementState> {
  EnforcementCubit(this._list, this._appeal) : super(const EnforcementState());

  final ListEnforcementNotices _list;
  final SubmitAppeal _appeal;

  /// One key per notice: retries of the same appeal reuse it.
  final Map<String, IdempotencyKey> _appealKeys = {};

  Future<void> load() async {
    emit(const EnforcementState(status: EnforcementStatus.loading));
    final result = await _list(const PageRequest(limit: 50));
    emit(switch (result) {
      Success(:final value) => EnforcementState(
        status: EnforcementStatus.loaded,
        notices: value.items,
      ),
      Err(:final failure) => EnforcementState(
        status: EnforcementStatus.failed,
        failure: failure,
      ),
    });
  }

  Future<void> appeal(String enforcementId, String statement) async {
    final text = statement.trim();
    if (text.isEmpty || text.length > appealStatementMaxLength) return;
    final key = _appealKeys.putIfAbsent(enforcementId, IdempotencyKey.generate);
    emit(state.copyWith(appealing: enforcementId, clearAppealFailure: true));
    final result = await _appeal((
      enforcementId: enforcementId,
      statement: text,
      idempotencyKey: key,
    ));
    emit(switch (result) {
      Success() => state.copyWith(
        appealed: {...state.appealed, enforcementId},
        clearAppealing: true,
      ),
      // Already appealed: treat as submitted.
      Err(failure: ConflictFailure() || BusinessRuleFailure()) =>
        state.copyWith(
          appealed: {...state.appealed, enforcementId},
          clearAppealing: true,
        ),
      Err(:final failure) => state.copyWith(
        appealFailure: failure,
        clearAppealing: true,
      ),
    });
  }
}

enum EnforcementStatus { loading, loaded, failed }

final class EnforcementState extends Equatable {
  const EnforcementState({
    this.status = EnforcementStatus.loading,
    this.notices = const [],
    this.failure,
    this.appealing,
    this.appealed = const {},
    this.appealFailure,
  });

  final EnforcementStatus status;
  final List<EnforcementNotice> notices;
  final Failure? failure;

  /// Notice id whose appeal is being sent.
  final String? appealing;

  /// Notice ids appealed in this session.
  final Set<String> appealed;
  final Failure? appealFailure;

  EnforcementState copyWith({
    Set<String>? appealed,
    String? appealing,
    Failure? appealFailure,
    bool clearAppealing = false,
    bool clearAppealFailure = false,
  }) => EnforcementState(
    status: status,
    notices: notices,
    failure: failure,
    appealing: clearAppealing ? null : (appealing ?? this.appealing),
    appealed: appealed ?? this.appealed,
    appealFailure: clearAppealFailure
        ? null
        : (appealFailure ?? this.appealFailure),
  );

  @override
  List<Object?> get props => [
    status,
    notices,
    failure,
    appealing,
    appealed,
    appealFailure,
  ];
}
