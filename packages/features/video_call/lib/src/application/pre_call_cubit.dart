import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/call_session.dart';
import '../domain/entities/pre_call_info.dart';
import '../domain/usecases/get_pre_call_info.dart';
import '../domain/usecases/request_call.dart';

sealed class PreCallState extends Equatable {
  const PreCallState();

  @override
  List<Object?> get props => [];
}

final class PreCallLoading extends PreCallState {
  const PreCallLoading();
}

final class PreCallFailed extends PreCallState {
  const PreCallFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// V01 (or V06 when [insufficient]). [requestFailure] is set when the call
/// request was refused (e.g. `host_busy`).
final class PreCallReady extends PreCallState {
  const PreCallReady(
    this.info, {
    this.requesting = false,
    this.requestFailure,
    this.serverSaysInsufficient = false,
  });

  final PreCallInfo info;
  final bool requesting;
  final Failure? requestFailure;
  final bool serverSaysInsufficient;

  /// V06: below 60 s at the host's rate (client hint or server refusal).
  bool get insufficient => serverSaysInsufficient || !info.hasMinimumBalance;

  @override
  List<Object?> get props => [
    info,
    requesting,
    requestFailure,
    serverSaysInsufficient,
  ];
}

/// The server created the call; the page opens the call screen.
final class PreCallStarted extends PreCallState {
  const PreCallStarted(this.session);

  final CallSession session;

  @override
  List<Object?> get props => [session];
}

/// V01/V06: shows the host's rate and own balance, then requests the call
/// (POST /v1/calls) with one idempotency key per "Start video call" intent.
final class PreCallCubit extends Cubit<PreCallState> {
  PreCallCubit({
    required GetPreCallInfo getInfo,
    required RequestCall requestCall,
  }) : _getInfo = getInfo,
       _requestCall = requestCall,
       super(const PreCallLoading());

  final GetPreCallInfo _getInfo;
  final RequestCall _requestCall;
  IdempotencyKey _key = IdempotencyKey.generate();

  Future<void> load(String hostUserId) async {
    emit(const PreCallLoading());
    final result = await _getInfo(hostUserId);
    emit(switch (result) {
      Success(:final value) => PreCallReady(value),
      Err(:final failure) => PreCallFailed(failure),
    });
  }

  Future<void> startCall() async {
    final s = state;
    if (s is! PreCallReady || s.requesting || s.insufficient) return;
    emit(PreCallReady(s.info, requesting: true));
    final result = await _requestCall((
      hostUserId: s.info.hostUserId,
      idempotencyKey: _key,
    ));
    switch (result) {
      case Success(:final value):
        _key = IdempotencyKey.generate();
        emit(PreCallStarted(value));
      case Err(:final failure):
        // Business refusals end this intent; a network error keeps the key
        // so a retry replays the same request.
        if (failure is BusinessRuleFailure) _key = IdempotencyKey.generate();
        emit(
          PreCallReady(
            s.info,
            requestFailure: failure,
            serverSaysInsufficient: failure.code == 'insufficient_diamonds',
          ),
        );
    }
  }
}
