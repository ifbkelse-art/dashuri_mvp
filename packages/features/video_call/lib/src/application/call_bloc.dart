import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/call_event.dart';
import '../domain/entities/call_session.dart';
import '../domain/entities/media_event.dart';
import '../domain/ports/video_engine.dart';
import '../domain/usecases/accept_call.dart';
import '../domain/usecases/decline_call.dart';
import '../domain/usecases/end_call.dart';
import '../domain/usecases/get_call_credentials.dart';
import '../domain/usecases/request_call.dart';
import '../domain/usecases/watch_call.dart';

part 'call_event_bloc.dart';
part 'call_state.dart';

/// Orchestrates one call on the device: API lifecycle + media engine +
/// server events. It never counts billable time; it displays the server's
/// `billedSeconds`/`diamondsCharged` from `CallUpdated` events.
final class CallBloc extends Bloc<CallBlocEvent, CallState> {
  CallBloc({
    required RequestCall requestCall,
    required AcceptCall acceptCall,
    required DeclineCall declineCall,
    required EndCall endCall,
    required GetCallCredentials getCredentials,
    required WatchCall watchCall,
    required VideoEngine engine,
  }) : _requestCall = requestCall,
       _acceptCall = acceptCall,
       _declineCall = declineCall,
       _endCall = endCall,
       _getCredentials = getCredentials,
       _watchCall = watchCall,
       _engine = engine,
       super(const CallState()) {
    on<CallOutgoingRequested>(_onOutgoing);
    on<CallIncomingAccepted>(_onAccepted);
    on<CallIncomingDeclined>(_onDeclined);
    on<CallEndRequested>(_onEnd);
    on<CallServerEventReceived>(_onServerEvent);
    on<CallMediaEventReceived>(_onMediaEvent);
  }

  final RequestCall _requestCall;
  final AcceptCall _acceptCall;
  final DeclineCall _declineCall;
  final EndCall _endCall;
  final GetCallCredentials _getCredentials;
  final WatchCall _watchCall;
  final VideoEngine _engine;
  StreamSubscription<CallEvent>? _serverSub;
  StreamSubscription<MediaEvent>? _mediaSub;

  /// One key for the "call this host" intent and one for "end this call".
  final IdempotencyKey _requestKey = IdempotencyKey.generate();
  final IdempotencyKey _endKey = IdempotencyKey.generate();

  Future<void> _onOutgoing(
    CallOutgoingRequested e,
    Emitter<CallState> emit,
  ) async {
    emit(state.copyWith(status: CallUiStatus.requesting));
    final result = await _requestCall((
      hostUserId: e.hostUserId,
      idempotencyKey: _requestKey,
    ));
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(status: CallUiStatus.ringing, session: value));
        _listen(value.callId);
      case Err(:final failure):
        emit(state.copyWith(status: CallUiStatus.failed, failure: failure));
    }
  }

  Future<void> _onAccepted(
    CallIncomingAccepted e,
    Emitter<CallState> emit,
  ) async {
    emit(state.copyWith(status: CallUiStatus.connecting));
    final result = await _acceptCall(e.callId);
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(session: value));
        _listen(value.callId);
        await _joinMedia(value.callId, emit);
      case Err(:final failure):
        emit(state.copyWith(status: CallUiStatus.failed, failure: failure));
    }
  }

  Future<void> _onDeclined(
    CallIncomingDeclined e,
    Emitter<CallState> emit,
  ) async {
    await _declineCall(e.callId);
    emit(state.copyWith(status: CallUiStatus.ended));
  }

  Future<void> _onEnd(CallEndRequested e, Emitter<CallState> emit) async {
    final callId = state.session?.callId;
    await _engine.leave();
    if (callId == null) return emit(state.copyWith(status: CallUiStatus.ended));
    emit(state.copyWith(status: CallUiStatus.ending));
    final result = await _endCall((
      callId: callId,
      reason: e.reason,
      idempotencyKey: _endKey,
    ));
    emit(switch (result) {
      Success(:final value) => state.copyWith(
        status: CallUiStatus.ended,
        session: value,
      ),
      // The server also ends calls on its own (disconnect timeout), so a
      // failed end request is shown but not retried in a loop.
      Err(:final failure) => state.copyWith(
        status: CallUiStatus.ended,
        failure: failure,
      ),
    });
  }

  Future<void> _onServerEvent(
    CallServerEventReceived e,
    Emitter<CallState> emit,
  ) async {
    switch (e.event) {
      case CallUpdated(:final session):
        final status = switch (session.phase) {
          CallPhase.accepted || CallPhase.connecting => CallUiStatus.connecting,
          CallPhase.active => CallUiStatus.active,
          CallPhase.paused => CallUiStatus.paused,
          CallPhase.ended ||
          CallPhase.declined ||
          CallPhase.missed ||
          CallPhase.failed => CallUiStatus.ended,
          _ => state.status,
        };
        emit(state.copyWith(status: status, session: session));
        // Caller joins media once the receiver has accepted.
        if (session.role == CallRole.caller &&
            session.phase == CallPhase.accepted &&
            !state.mediaJoined) {
          await _joinMedia(session.callId, emit);
        }
        if (status == CallUiStatus.ended) await _engine.leave();
      case CallLowBalance(:final secondsRemaining):
        emit(state.copyWith(lowBalanceSecondsRemaining: secondsRemaining));
    }
  }

  void _onMediaEvent(CallMediaEventReceived e, Emitter<CallState> emit) {
    final reconnecting = switch (e.event) {
      MediaEvent.connectionLost => true,
      MediaEvent.connectionRestored => false,
      _ => null,
    };
    if (reconnecting != null) emit(state.copyWith(reconnecting: reconnecting));
  }

  Future<void> _joinMedia(String callId, Emitter<CallState> emit) async {
    final creds = await _getCredentials(callId);
    switch (creds) {
      case Err(:final failure):
        emit(state.copyWith(status: CallUiStatus.failed, failure: failure));
      case Success(:final value):
        _mediaSub ??= _engine.events().listen(
          (m) => add(CallMediaEventReceived(m)),
        );
        final joined = await _engine.join(value);
        emit(switch (joined) {
          Success() => state.copyWith(mediaJoined: true),
          Err(:final failure) => state.copyWith(
            status: CallUiStatus.failed,
            failure: failure,
          ),
        });
    }
  }

  void _listen(String callId) {
    _serverSub ??= _watchCall(
      callId,
    ).listen((ev) => add(CallServerEventReceived(ev)));
  }

  @override
  Future<void> close() async {
    await _serverSub?.cancel();
    await _mediaSub?.cancel();
    await _engine.leave();
    return super.close();
  }
}
