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
import '../domain/usecases/get_call.dart';
import '../domain/usecases/get_call_credentials.dart';
import '../domain/usecases/request_call.dart';
import '../domain/usecases/watch_call.dart';
import 'moderation_frame_scheduler.dart';

part 'call_event_bloc.dart';
part 'call_state.dart';

/// Orchestrates one call on the device: API lifecycle + media engine +
/// server events. It never counts billable time; it displays the server's
/// `billedSeconds`/`diamondsCharged` from `CallUpdated` events.
// Not final: page tests mock it.
class CallBloc extends Bloc<CallBlocEvent, CallState> {
  CallBloc({
    required RequestCall requestCall,
    required AcceptCall acceptCall,
    required DeclineCall declineCall,
    required EndCall endCall,
    required GetCallCredentials getCredentials,
    required WatchCall watchCall,
    required VideoEngine engine,
    GetCall? getCall,
    ModerationFrameScheduler? moderation,
    Duration refreshInterval = const Duration(seconds: 5),
  }) : _requestCall = requestCall,
       _acceptCall = acceptCall,
       _declineCall = declineCall,
       _endCall = endCall,
       _getCredentials = getCredentials,
       _watchCall = watchCall,
       _engine = engine,
       _getCall = getCall,
       _moderation = moderation,
       _refreshInterval = refreshInterval,
       super(const CallState()) {
    on<CallOutgoingRequested>(_onOutgoing);
    on<CallAttachRequested>(_onAttach);
    on<CallIncomingAccepted>(_onAccepted);
    on<CallIncomingDeclined>(_onDeclined);
    on<CallEndRequested>(_onEnd);
    on<CallServerEventReceived>(_onServerEvent);
    on<CallMediaEventReceived>(_onMediaEvent);
    on<CallMicrophoneToggled>(_onMic);
    on<CallCameraToggled>(_onCamera);
    on<CallRefreshTicked>(_onRefresh);
  }

  final RequestCall _requestCall;
  final AcceptCall _acceptCall;
  final DeclineCall _declineCall;
  final EndCall _endCall;
  final GetCallCredentials _getCredentials;
  final WatchCall _watchCall;
  final VideoEngine _engine;
  final GetCall? _getCall;
  final ModerationFrameScheduler? _moderation;
  final Duration _refreshInterval;
  StreamSubscription<CallEvent>? _serverSub;
  StreamSubscription<MediaEvent>? _mediaSub;
  Timer? _refreshTimer;
  bool _joining = false;

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

  Future<void> _onAttach(CallAttachRequested e, Emitter<CallState> emit) async {
    final getCall = _getCall;
    if (getCall == null) return;
    emit(
      state.copyWith(
        status: e.incoming ? CallUiStatus.incoming : CallUiStatus.requesting,
      ),
    );
    final result = await getCall(e.callId);
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(status: CallUiStatus.failed, failure: failure));
      case Success(:final value):
        _listen(value.callId);
        await _apply(value, emit);
        // A receiver who accepted elsewhere, or a caller arriving late,
        // joins media as soon as the server says the call is accepted.
        if (!state.mediaJoined &&
            const {
              CallPhase.accepted,
              CallPhase.connecting,
              CallPhase.active,
              CallPhase.paused,
            }.contains(value.phase)) {
          await _joinMedia(value.callId, emit);
        }
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
    _stopBackground();
    final result = await _declineCall(e.callId);
    emit(
      state.copyWith(
        status: CallUiStatus.ended,
        session: result is Success<CallSession> ? result.value : null,
        requestedEndReason: 'declined',
      ),
    );
  }

  Future<void> _onEnd(CallEndRequested e, Emitter<CallState> emit) async {
    if (state.status == CallUiStatus.ending ||
        state.status == CallUiStatus.ended) {
      return;
    }
    final callId = state.session?.callId;
    _stopBackground();
    await _engine.leave();
    if (callId == null) {
      return emit(
        state.copyWith(
          status: CallUiStatus.ended,
          requestedEndReason: e.reason,
        ),
      );
    }
    emit(
      state.copyWith(status: CallUiStatus.ending, requestedEndReason: e.reason),
    );
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
    if (state.status == CallUiStatus.ended) return;
    switch (e.event) {
      // After a local failure (e.g. camera/microphone could not join), stay
      // on the failure screen — it offers "End call" — until the server
      // reports a terminal phase. Re-applying a waiting snapshot would flip
      // the UI back to "Connecting…" and silently retry the join forever.
      case CallUpdated(:final session)
          when state.status == CallUiStatus.failed && !session.phase.isTerminal:
        emit(
          state.copyWith(
            session: session.withPeerFrom(state.session),
            failure: state.failure, // copyWith clears it otherwise
          ),
        );
      case CallUpdated(:final session):
        await _apply(session, emit);
        // Caller joins media once the receiver has accepted.
        if (session.role == CallRole.caller &&
            (session.phase == CallPhase.accepted ||
                session.phase == CallPhase.connecting) &&
            !state.mediaJoined) {
          await _joinMedia(session.callId, emit);
        }
      case CallLowBalance(:final secondsRemaining):
        emit(state.copyWith(lowBalanceSecondsRemaining: secondsRemaining));
      case CallModerationEnded():
        emit(state.copyWith(endedByModeration: true));
    }
  }

  Future<void> _onRefresh(CallRefreshTicked e, Emitter<CallState> emit) async {
    final callId = state.session?.callId;
    final getCall = _getCall;
    if (callId == null || getCall == null) return;
    final result = await getCall(callId);
    if (result case Success(:final value)) {
      add(CallServerEventReceived(CallUpdated(value)));
    }
  }

  /// Applies a server snapshot: status, moderation window, polling, media.
  Future<void> _apply(CallSession incoming, Emitter<CallState> emit) async {
    final session = incoming.withPeerFrom(state.session);
    final status = switch (session.phase) {
      CallPhase.requested || CallPhase.ringing =>
        session.role == CallRole.receiver
            ? CallUiStatus.incoming
            : CallUiStatus.ringing,
      CallPhase.accepted || CallPhase.connecting => CallUiStatus.connecting,
      CallPhase.active => CallUiStatus.active,
      CallPhase.paused => CallUiStatus.paused,
      CallPhase.ending => CallUiStatus.ending,
      CallPhase.ended ||
      CallPhase.declined ||
      CallPhase.missed ||
      CallPhase.failed => CallUiStatus.ended,
    };
    emit(state.copyWith(status: status, session: session));
    final window = session.moderationWindowEndsAt;
    if (status == CallUiStatus.active && window != null) {
      _moderation?.start(callId: session.callId, windowEndsAt: window);
    }
    final waiting =
        status == CallUiStatus.ringing ||
        status == CallUiStatus.incoming ||
        status == CallUiStatus.connecting;
    if (waiting) {
      _refreshTimer ??= Timer.periodic(
        _refreshInterval,
        (_) => add(const CallRefreshTicked()),
      );
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
    if (status == CallUiStatus.ended) {
      _stopBackground();
      await _engine.leave();
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

  Future<void> _onMic(CallMicrophoneToggled e, Emitter<CallState> emit) async {
    final on = !state.microphoneOn;
    await _engine.setMicrophoneEnabled(enabled: on);
    emit(state.copyWith(microphoneOn: on));
  }

  Future<void> _onCamera(CallCameraToggled e, Emitter<CallState> emit) async {
    final on = !state.cameraOn;
    await _engine.setCameraEnabled(enabled: on);
    emit(state.copyWith(cameraOn: on));
  }

  Future<void> _joinMedia(String callId, Emitter<CallState> emit) async {
    if (_joining || state.mediaJoined) return;
    _joining = true;
    try {
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
    } finally {
      _joining = false;
    }
  }

  void _listen(String callId) {
    _serverSub ??= _watchCall(
      callId,
    ).listen((ev) => add(CallServerEventReceived(ev)));
  }

  void _stopBackground() {
    _moderation?.stop();
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  Future<void> close() async {
    _stopBackground();
    await _serverSub?.cancel();
    await _mediaSub?.cancel();
    await _engine.leave();
    return super.close();
  }
}
