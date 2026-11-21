import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_status.dart';
import '../domain/entities/kyc_session.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/start_kyc.dart';
import 'host_application_flow.dart';

enum HostVerificationStatus { loading, loadFailed, ready, starting }

final class HostVerificationState extends Equatable {
  const HostVerificationState({
    this.status = HostVerificationStatus.loading,
    this.host,
    this.session,
    this.failure,
    this.sessionStartedNow = false,
  });

  final HostVerificationStatus status;
  final HostStatus? host;
  final KycSession? session;
  final Failure? failure;

  /// True right after POST /v1/host/kyc/sessions succeeded; the page then
  /// continues to profile setup (H09).
  final bool sessionStartedNow;

  HostApplicationStep? get step =>
      host == null ? null : nextApplicationStep(host!);

  @override
  List<Object?> get props => [
    status,
    host,
    session,
    failure,
    sessionStartedNow,
  ];
}

/// H03–H05 (manual identity review), H07 (under review) and H08 (needs
/// attention). The MVP KYC provider is manual: starting a session puts the
/// host in staff review; no documents are uploaded from the app.
final class HostVerificationCubit extends Cubit<HostVerificationState> {
  HostVerificationCubit(this._getHostStatus, this._startKyc)
    : super(const HostVerificationState());

  final GetHostStatus _getHostStatus;
  final StartKyc _startKyc;
  IdempotencyKey? _kycKey;

  Future<void> load() async {
    emit(HostVerificationState(session: state.session));
    final result = await _getHostStatus(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => HostVerificationState(
        status: HostVerificationStatus.ready,
        host: value,
        session: state.session,
      ),
      Err(:final failure) => HostVerificationState(
        status: HostVerificationStatus.loadFailed,
        failure: failure,
      ),
    });
  }

  /// POST /v1/host/kyc/sessions (also used to start again after a rejection).
  Future<void> startVerification() async {
    if (state.status == HostVerificationStatus.starting) return;
    final key = _kycKey ??= IdempotencyKey.generate();
    emit(
      HostVerificationState(
        status: HostVerificationStatus.starting,
        host: state.host,
        session: state.session,
      ),
    );
    final result = await _startKyc(key);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        _kycKey = null;
        final status = await _getHostStatus(const NoInput());
        if (isClosed) return;
        emit(
          HostVerificationState(
            status: HostVerificationStatus.ready,
            host: switch (status) {
              Success(:final value) => value,
              Err() => state.host,
            },
            session: value,
            sessionStartedNow: true,
          ),
        );
      case Err(failure: BusinessRuleFailure(code: 'kyc_not_required')):
        _kycKey = null;
        await load();
      case Err(:final failure):
        emit(
          HostVerificationState(
            status: HostVerificationStatus.ready,
            host: state.host,
            session: state.session,
            failure: failure,
          ),
        );
    }
  }
}
