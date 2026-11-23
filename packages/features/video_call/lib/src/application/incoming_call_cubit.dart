import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/call_session.dart';
import '../domain/usecases/get_call_history.dart';
import '../domain/usecases/watch_incoming_calls.dart';

final class IncomingCallState extends Equatable {
  const IncomingCallState({this.callId, this.sequence = 0});

  /// The latest ringing call for this user, or null before any.
  final String? callId;

  /// Increments per new ring so listeners react to every one.
  final int sequence;

  @override
  List<Object?> get props => [callId, sequence];
}

/// Says whether this device should be checking for incoming calls right now
/// (the app registers: host online with the app in the foreground). The
/// video-call feature does not know about host presence, so it is injected.
final class IncomingCallCheckGate {
  const IncomingCallCheckGate(this.isExpectingCalls);

  final bool Function() isExpectingCalls;
}

/// Watches `user:<currentUserId>` for ringing calls where the user is the
/// receiver (V16). Each call id is reported once.
///
/// Realtime is only a hint: a dropped channel or a missed message would lose
/// the ring (a call rings for 30 s). So while [gate] says calls are expected,
/// the cubit also checks the newest calls every [backupInterval] and reports
/// any that is ringing for this user.
// Not final: page tests mock it.
class IncomingCallCubit extends Cubit<IncomingCallState> {
  IncomingCallCubit(
    this._watch, {
    GetCallHistory? recentCalls,
    IncomingCallCheckGate? gate,
    this.backupInterval = const Duration(seconds: 5),
  }) : _recentCalls = recentCalls,
       _gate = gate,
       super(const IncomingCallState());

  final WatchIncomingCalls _watch;
  final GetCallHistory? _recentCalls;
  final IncomingCallCheckGate? _gate;
  final Duration backupInterval;

  StreamSubscription<CallSession>? _sub;
  Timer? _backup;
  bool _checking = false;
  final _seen = <String>{};

  void start() {
    _sub ??= _watch(const NoInput()).listen(
      _report,
      // Realtime is a hint; a dropped channel must not crash the app.
      onError: (Object _) {},
    );
    if (_recentCalls != null && _gate != null) {
      _backup ??= Timer.periodic(backupInterval, (_) => unawaited(checkNow()));
    }
  }

  /// One backup check: reports a call that is ringing for this user. Skipped
  /// when the gate is closed or a check is still running.
  Future<void> checkNow() async {
    final recent = _recentCalls;
    final gate = _gate;
    if (recent == null || gate == null || _checking || isClosed) return;
    if (!gate.isExpectingCalls()) return;
    _checking = true;
    try {
      final result = await recent(const PageRequest(limit: 5));
      if (result case Success(:final value)) {
        for (final c in value.items) {
          if (c.role == CallRole.receiver && c.phase == CallPhase.ringing) {
            _report(c);
          }
        }
      }
      // Errors are ignored: the next tick (or realtime) catches up.
    } finally {
      _checking = false;
    }
  }

  void _report(CallSession call) {
    if (isClosed || !_seen.add(call.callId)) return;
    emit(IncomingCallState(callId: call.callId, sequence: state.sequence + 1));
  }

  @override
  Future<void> close() async {
    _backup?.cancel();
    await _sub?.cancel();
    return super.close();
  }
}
