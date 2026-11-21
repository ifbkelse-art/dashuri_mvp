import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_status.dart';
import '../domain/usecases/apply_as_host.dart';
import '../domain/usecases/get_host_status.dart';
import 'host_application_flow.dart';

enum HostApplicationStatus { loading, loadFailed, ready, submitting }

final class HostApplicationState extends Equatable {
  const HostApplicationState({
    this.status = HostApplicationStatus.loading,
    this.host,
    this.failure,
    this.appliedNow = false,
  });

  final HostApplicationStatus status;
  final HostStatus? host;

  /// Load failure (status loadFailed) or the last apply failure (ready).
  final Failure? failure;

  /// True once POST /v1/host/application succeeded in this session; the
  /// page then moves on to the agreement (H06).
  final bool appliedNow;

  HostApplicationStep get nextStep =>
      host == null ? HostApplicationStep.apply : nextApplicationStep(host!);

  @override
  List<Object?> get props => [status, host, failure, appliedNow];
}

/// H01 intro and H02 steps: reads the host status and submits the
/// application (POST /v1/host/application) with one idempotency key per tap
/// intent, reused on retry.
final class HostApplicationCubit extends Cubit<HostApplicationState> {
  HostApplicationCubit(this._getHostStatus, this._applyAsHost)
    : super(const HostApplicationState());

  final GetHostStatus _getHostStatus;
  final ApplyAsHost _applyAsHost;
  IdempotencyKey? _applyKey;

  Future<void> load() async {
    emit(const HostApplicationState());
    final result = await _getHostStatus(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => HostApplicationState(
        status: HostApplicationStatus.ready,
        host: value,
      ),
      Err(:final failure) => HostApplicationState(
        status: HostApplicationStatus.loadFailed,
        failure: failure,
      ),
    });
  }

  Future<void> apply() async {
    if (state.status == HostApplicationStatus.submitting) return;
    final key = _applyKey ??= IdempotencyKey.generate();
    emit(
      HostApplicationState(
        status: HostApplicationStatus.submitting,
        host: state.host,
      ),
    );
    final result = await _applyAsHost(key);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        _applyKey = null;
        emit(
          HostApplicationState(
            status: HostApplicationStatus.ready,
            host: value,
            appliedNow: true,
          ),
        );
      case Err(failure: BusinessRuleFailure(code: 'already_applied')):
        _applyKey = null;
        final status = await _getHostStatus(const NoInput());
        if (isClosed) return;
        emit(
          HostApplicationState(
            status: HostApplicationStatus.ready,
            host: switch (status) {
              Success(:final value) => value,
              Err() => state.host,
            },
            appliedNow: true,
          ),
        );
      case Err(:final failure):
        emit(
          HostApplicationState(
            status: HostApplicationStatus.ready,
            host: state.host,
            failure: failure,
          ),
        );
    }
  }
}
