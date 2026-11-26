import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_status.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/set_availability.dart';
import 'host_presence_controller.dart';

part 'host_session_event.dart';
part 'host_session_state.dart';

/// The host's online session on Host Home (2026-11-26): one explicit state
/// per situation instead of overlapping booleans.
///
/// Incoming calls have absolute priority: the app reports a ring through
/// [HostPresenceController.notifyIncomingCall] before it opens the call
/// screen, and this bloc moves to [HostSessionIncomingCall] at once. Opening
/// Host Home never changes availability by itself.
final class HostSessionBloc extends Bloc<HostSessionEvent, HostSessionState> {
  HostSessionBloc({
    required GetHostStatus getStatus,
    required SetAvailability setAvailability,
    required HostPresenceController presence,
    DateTime Function()? now,
  }) : _getStatus = getStatus,
       _setAvailability = setAvailability,
       _presence = presence,
       _now = now ?? (() => DateTime.now().toUtc()),
       super(const HostSessionLoading()) {
    on<HostSessionStarted>(_onStarted);
    on<HostSessionGoOnlinePressed>(_onGoOnline);
    on<HostSessionActivationProceed>(_onProceed);
    on<HostSessionActivationCancelled>(_onCancelActivation);
    on<HostSessionGoOfflinePressed>(_onGoOffline);
    on<HostSessionIncomingCall>(_onIncoming);
    on<HostSessionNetworkChanged>(_onNetwork);
    on<HostSessionHeartbeatRefused>(_onRefused);
    on<HostSessionRetryPressed>(_onRetry);
    _subs = [
      _presence.incomingCalls.listen((id) => add(HostSessionIncomingCall(id))),
      _presence.networkHealthy.listen(
        (ok) => add(
          HostSessionNetworkChanged(
            healthy: ok,
            failures: _presence.networkFailures,
          ),
        ),
      ),
      _presence.heartbeatRejected.listen(
        (f) => add(HostSessionHeartbeatRefused(f)),
      ),
    ];
  }

  final GetHostStatus _getStatus;
  final SetAvailability _setAvailability;
  final HostPresenceController _presence;
  final DateTime Function() _now;
  late final List<StreamSubscription<Object>> _subs;

  /// Consecutive heartbeat network failures before "network unavailable".
  static const unavailableAfter = 3;

  HostStatus? get _status => switch (state) {
    final HostSessionWithStatus s => s.status,
    _ => null,
  };

  DateTime _since(HostStatus s) => s.onlineSince ?? _now();

  Future<void> _onStarted(
    HostSessionStarted e,
    Emitter<HostSessionState> emit,
  ) async {
    emit(const HostSessionLoading());
    final r = await _getStatus(const NoInput());
    switch (r) {
      case Err(:final failure):
        emit(HostSessionLoadFailed(failure));
      case Success(:final value):
        if (!value.isApproved) {
          emit(
            HostSessionUnavailable(
              value,
              reason: value.isSuspended
                  ? UnavailableReason.suspended
                  : UnavailableReason.notApproved,
            ),
          );
          return;
        }
        _presence.setOnline(online: value.isAvailable);
        if (value.isAvailable) {
          emit(HostSessionOnline(value, since: _since(value), notice: e.after));
        } else if (e.activate) {
          emit(HostSessionGoingOnline(value));
        } else {
          emit(HostSessionOffline(value));
        }
    }
  }

  void _onGoOnline(
    HostSessionGoOnlinePressed e,
    Emitter<HostSessionState> emit,
  ) {
    final s = state;
    if (s is HostSessionOffline || s is HostSessionSessionEnded) {
      emit(HostSessionGoingOnline((s as HostSessionWithStatus).status));
    }
  }

  void _onCancelActivation(
    HostSessionActivationCancelled e,
    Emitter<HostSessionState> emit,
  ) {
    if (state case HostSessionGoingOnline(:final status)) {
      emit(HostSessionOffline(status));
    }
  }

  /// After the arrival-photo step (captured or skipped): go online. Skipping
  /// the photo never blocks or changes this.
  Future<void> _onProceed(
    HostSessionActivationProceed e,
    Emitter<HostSessionState> emit,
  ) async {
    final s = state;
    if (s is! HostSessionGoingOnline || s.activating) return;
    emit(HostSessionGoingOnline(s.status, activating: true));
    final r = await _setAvailability(true);
    switch (r) {
      case Success(:final value):
        _presence.setOnline(online: value.isAvailable);
        emit(
          value.isAvailable
              ? HostSessionOnline(value, since: _since(value))
              : HostSessionOffline(value),
        );
      case Err(:final failure):
        emit(
          failure is NetworkFailure
              ? HostSessionOffline(s.status, failure: failure)
              : failure is ForbiddenFailure ||
                    failure.code == 'account_restricted'
              ? HostSessionUnavailable(
                  s.status,
                  reason: UnavailableReason.restricted,
                  failure: failure,
                )
              : HostSessionOffline(s.status, failure: failure),
        );
    }
  }

  Future<void> _onGoOffline(
    HostSessionGoOfflinePressed e,
    Emitter<HostSessionState> emit,
  ) async {
    final status = _status;
    final s = state;
    if (status == null ||
        s is HostSessionGoingOffline ||
        s is HostSessionOffline) {
      return;
    }
    final since = s is HostSessionOnlineLike ? s.since : _now();
    emit(HostSessionGoingOffline(status, since: since));
    final r = await _setAvailability(false);
    switch (r) {
      case Success(:final value):
        _presence.setOnline(online: false);
        emit(
          HostSessionSessionEnded(
            value,
            duration: _now().difference(since),
            reason: SessionEndReason.wentOffline,
          ),
        );
      case Err(:final failure):
        // e.g. in_call: still online.
        emit(HostSessionOnline(status, since: since, failure: failure));
    }
  }

  void _onIncoming(HostSessionIncomingCall e, Emitter<HostSessionState> emit) {
    final s = state;
    if (s is HostSessionOnlineLike) {
      emit(HostSessionRinging(s.status, since: s.since, callId: e.callId));
    }
  }

  void _onNetwork(HostSessionNetworkChanged e, Emitter<HostSessionState> emit) {
    final s = state;
    if (s is! HostSessionOnlineLike || s is HostSessionRinging) return;
    if (e.healthy) {
      emit(HostSessionOnline(s.status, since: s.since));
    } else if (e.failures >= unavailableAfter) {
      emit(HostSessionNetworkUnavailable(s.status, since: s.since));
    } else {
      emit(HostSessionReconnecting(s.status, since: s.since));
    }
  }

  /// The server refused a heartbeat (taken offline, restricted, suspended).
  Future<void> _onRefused(
    HostSessionHeartbeatRefused e,
    Emitter<HostSessionState> emit,
  ) async {
    final s = state;
    final status = _status;
    if (status == null) return;
    final since = s is HostSessionOnlineLike ? s.since : _now();
    final r = await _getStatus(const NoInput());
    final fresh = r is Success<HostStatus>
        ? r.value
        : status.copyWith(isAvailable: false);
    if (!fresh.isApproved || e.failure is ForbiddenFailure) {
      emit(
        HostSessionUnavailable(
          fresh,
          reason: UnavailableReason.restricted,
          failure: e.failure,
        ),
      );
    } else {
      emit(
        HostSessionSessionEnded(
          fresh,
          duration: _now().difference(since),
          reason: SessionEndReason.endedByServer,
        ),
      );
    }
  }

  Future<void> _onRetry(
    HostSessionRetryPressed e,
    Emitter<HostSessionState> emit,
  ) async {
    final s = state;
    if (s is HostSessionReconnecting || s is HostSessionNetworkUnavailable) {
      await _presence.beatNow();
    } else if (s is HostSessionLoadFailed) {
      add(const HostSessionStarted());
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
