import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/messaging_privacy.dart';
import '../domain/usecases/settings_usecases.dart';

/// S04 who can message me. Changes apply optimistically and revert on error.
class PrivacyCubit extends Cubit<PrivacyState> {
  PrivacyCubit(this._get, this._set) : super(const PrivacyState());

  final GetMessagingPrivacy _get;
  final SetMessagingPrivacy _set;

  Future<void> load() async {
    emit(const PrivacyState());
    final result = await _get(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => PrivacyState(
        status: PrivacyStatus.ready,
        value: value,
      ),
      Err(:final failure) => PrivacyState(
        status: PrivacyStatus.failed,
        failure: failure,
      ),
    });
  }

  Future<void> select(WhoCanMessage value) async {
    final previous = state.value;
    if (state.status != PrivacyStatus.ready || previous == value) return;
    emit(PrivacyState(status: PrivacyStatus.ready, value: value, saving: true));
    final result = await _set(value);
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => PrivacyState(
        status: PrivacyStatus.ready,
        value: value,
      ),
      Err(:final failure) => PrivacyState(
        status: PrivacyStatus.ready,
        value: previous,
        saveFailure: failure,
      ),
    });
  }
}

enum PrivacyStatus { loading, ready, failed }

final class PrivacyState extends Equatable {
  const PrivacyState({
    this.status = PrivacyStatus.loading,
    this.value,
    this.saving = false,
    this.failure,
    this.saveFailure,
  });

  final PrivacyStatus status;
  final WhoCanMessage? value;
  final bool saving;
  final Failure? failure;
  final Failure? saveFailure;

  @override
  List<Object?> get props => [status, value, saving, failure, saveFailure];
}
