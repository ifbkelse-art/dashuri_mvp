import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/free_call_request.dart';
import '../domain/usecases/get_free_call_request.dart';
import '../domain/usecases/get_integrity_token.dart';
import '../domain/usecases/request_free_call.dart';

sealed class FreeCallMatchState extends Equatable {
  const FreeCallMatchState();

  @override
  List<Object?> get props => [];
}

final class FreeCallMatchIdle extends FreeCallMatchState {
  const FreeCallMatchIdle();
}

/// C10 "Finding someone for you…" (integrity check, request and polling).
final class FreeCallMatchSearching extends FreeCallMatchState {
  const FreeCallMatchSearching();
}

final class FreeCallMatchFound extends FreeCallMatchState {
  const FreeCallMatchFound(this.callId);

  final String callId;

  @override
  List<Object?> get props => [callId];
}

/// No opted-in host was free; the card stays available.
final class FreeCallMatchNoHost extends FreeCallMatchState {
  const FreeCallMatchNoHost();
}

final class FreeCallMatchCancelled extends FreeCallMatchState {
  const FreeCallMatchCancelled();
}

final class FreeCallMatchFailed extends FreeCallMatchState {
  const FreeCallMatchFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// C10: Play Integrity token → POST /v1/free-call/requests (one
/// idempotency key per intent) → poll GET /v1/free-call/requests/{id}
/// every [pollInterval] until matched, for at most [timeout].
// Not final: page tests mock it.
class FreeCallMatchCubit extends Cubit<FreeCallMatchState> {
  FreeCallMatchCubit({
    required GetIntegrityToken integrity,
    required RequestFreeCall request,
    required GetFreeCallRequest getRequest,
    this.pollInterval = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 90),
  }) : _integrity = integrity,
       _request = request,
       _getRequest = getRequest,
       super(const FreeCallMatchIdle());

  final GetIntegrityToken _integrity;
  final RequestFreeCall _request;
  final GetFreeCallRequest _getRequest;
  final Duration pollInterval;
  final Duration timeout;

  IdempotencyKey _key = IdempotencyKey.generate();
  int _run = 0;

  Future<void> start() async {
    if (state is FreeCallMatchSearching) return;
    final run = ++_run;
    emit(const FreeCallMatchSearching());
    final token = await _integrity(const NoInput());
    if (run != _run) return;
    if (token case Err(:final failure)) {
      return emit(FreeCallMatchFailed(failure));
    }
    final result = await _request((
      idempotencyKey: _key,
      integrityToken: (token as Success<String>).value,
    ));
    if (run != _run) return;
    switch (result) {
      case Err(:final failure):
        // Keep the key after transport errors so a retry replays the
        // same request; a refusal ends this intent.
        if (failure is! NetworkFailure) _key = IdempotencyKey.generate();
        emit(FreeCallMatchFailed(failure));
      case Success(:final value):
        _key = IdempotencyKey.generate();
        await _follow(value, run);
    }
  }

  Future<void> _follow(FreeCallRequest request, int run) async {
    final deadline = DateTime.now().add(timeout);
    var current = request;
    while (run == _run) {
      if (current.isMatched) return emit(FreeCallMatchFound(current.callId!));
      if (current.status == 'no_host_available') {
        return emit(const FreeCallMatchNoHost());
      }
      if (current.status == 'cancelled') {
        return emit(const FreeCallMatchCancelled());
      }
      if (DateTime.now().isAfter(deadline)) {
        return emit(const FreeCallMatchNoHost());
      }
      await Future<void>.delayed(pollInterval);
      if (run != _run) return;
      final next = await _getRequest(current.requestId);
      if (run != _run) return;
      switch (next) {
        case Success(:final value):
          current = value;
        case Err(:final failure) when failure is! NetworkFailure:
          return emit(FreeCallMatchFailed(failure));
        case Err():
          break; // transient: keep polling until the deadline
      }
    }
  }

  /// Stops matching; the card stays unused unless the server matched.
  void cancel() {
    _run++;
    emit(const FreeCallMatchCancelled());
  }

  @override
  Future<void> close() {
    _run++;
    return super.close();
  }
}
