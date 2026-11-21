import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/consent_state.dart';
import '../domain/usecases/get_consents.dart';
import '../domain/usecases/update_consents.dart';

/// S05 notification and data consents (GET/PUT /v1/me/consents).
class ConsentsCubit extends Cubit<ConsentsState> {
  ConsentsCubit(this._get, this._update) : super(const ConsentsState());

  final GetConsents _get;
  final UpdateConsents _update;

  Future<void> load() async {
    emit(const ConsentsState());
    final result = await _get(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => ConsentsState(data: value),
      Err(:final failure) => ConsentsState(failure: failure),
    });
  }

  Future<void> setMarketing(bool value) =>
      _save(analytics: state.data?.analytics, marketing: value);

  Future<void> setAnalytics(bool value) =>
      _save(analytics: value, marketing: state.data?.marketing);

  Future<void> _save({
    required bool? analytics,
    required bool? marketing,
  }) async {
    final previous = state.data;
    if (previous == null || analytics == null || marketing == null) return;
    emit(
      ConsentsState(
        data: ConsentState(
          analytics: analytics,
          marketing: marketing,
          updatedAt: previous.updatedAt,
        ),
        saving: true,
      ),
    );
    final result = await _update((analytics: analytics, marketing: marketing));
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => ConsentsState(data: value),
      Err(:final failure) => ConsentsState(
        data: previous,
        saveFailure: failure,
      ),
    });
  }
}

final class ConsentsState extends Equatable {
  const ConsentsState({
    this.data,
    this.saving = false,
    this.failure,
    this.saveFailure,
  });

  /// Null while loading or after a load failure.
  final ConsentState? data;
  final bool saving;
  final Failure? failure;
  final Failure? saveFailure;

  bool get loading => data == null && failure == null;

  @override
  List<Object?> get props => [data, saving, failure, saveFailure];
}
