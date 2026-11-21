import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/call_session.dart';
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

/// Watches `user:<currentUserId>` for ringing calls where the user is the
/// receiver (V16). Each call id is reported once.
final class IncomingCallCubit extends Cubit<IncomingCallState> {
  IncomingCallCubit(this._watch) : super(const IncomingCallState());

  final WatchIncomingCalls _watch;
  StreamSubscription<CallSession>? _sub;
  final _seen = <String>{};

  void start() {
    _sub ??= _watch(const NoInput()).listen(
      (call) {
        if (!_seen.add(call.callId)) return;
        emit(
          IncomingCallState(callId: call.callId, sequence: state.sequence + 1),
        );
      },
      // Realtime is a hint; a dropped channel must not crash the app.
      onError: (Object _) {},
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
