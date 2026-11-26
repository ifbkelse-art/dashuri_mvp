part of 'host_session_bloc.dart';

/// What happened to the last call when the room reopens after it.
enum CallNotice {
  none,
  declined,
  missed,
  ended;

  static CallNotice parse(String? v) =>
      values.firstWhere((n) => n.name == v, orElse: () => none);
}

enum UnavailableReason { notApproved, suspended, restricted }

enum SessionEndReason { wentOffline, endedByServer }

sealed class HostSessionState extends Equatable {
  const HostSessionState();

  @override
  List<Object?> get props => [];
}

/// States that know the host's status.
sealed class HostSessionWithStatus extends HostSessionState {
  const HostSessionWithStatus(this.status);

  final HostStatus status;

  @override
  List<Object?> get props => [status];
}

/// States of an open online session (the host is listed and callable).
sealed class HostSessionOnlineLike extends HostSessionWithStatus {
  const HostSessionOnlineLike(super.status, {required this.since});

  /// When the current online session started (server time when known).
  final DateTime since;

  @override
  List<Object?> get props => [...super.props, since];
}

final class HostSessionLoading extends HostSessionState {
  const HostSessionLoading();
}

final class HostSessionLoadFailed extends HostSessionState {
  const HostSessionLoadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Offline. [failure]: the last attempt to go online failed.
final class HostSessionOffline extends HostSessionWithStatus {
  const HostSessionOffline(super.status, {this.failure});

  final Failure? failure;

  @override
  List<Object?> get props => [...super.props, failure];
}

/// Going online: the arrival-photo step, then the availability request
/// ([activating]).
final class HostSessionGoingOnline extends HostSessionWithStatus {
  const HostSessionGoingOnline(super.status, {this.activating = false});

  final bool activating;

  @override
  List<Object?> get props => [...super.props, activating];
}

/// Online and waiting for calls.
final class HostSessionOnline extends HostSessionOnlineLike {
  const HostSessionOnline(
    super.status, {
    required super.since,
    this.notice = CallNotice.none,
    this.failure,
  });

  /// Shown once after returning from a call.
  final CallNotice notice;

  /// A failed "go offline" (e.g. during a call).
  final Failure? failure;

  @override
  List<Object?> get props => [...super.props, notice, failure];
}

/// A call is ringing: the call screen opens.
final class HostSessionRinging extends HostSessionOnlineLike {
  const HostSessionRinging(
    super.status, {
    required super.since,
    required this.callId,
  });

  final String callId;

  @override
  List<Object?> get props => [...super.props, callId];
}

/// A heartbeat failed for network reasons; still listed for up to 90 s.
final class HostSessionReconnecting extends HostSessionOnlineLike {
  const HostSessionReconnecting(super.status, {required super.since});
}

/// Several heartbeats failed: the server will take the host offline soon.
final class HostSessionNetworkUnavailable extends HostSessionOnlineLike {
  const HostSessionNetworkUnavailable(super.status, {required super.since});
}

/// Cannot host right now (not approved, suspended, restricted).
final class HostSessionUnavailable extends HostSessionWithStatus {
  const HostSessionUnavailable(
    super.status, {
    required this.reason,
    this.failure,
  });

  final UnavailableReason reason;
  final Failure? failure;

  @override
  List<Object?> get props => [...super.props, reason, failure];
}

final class HostSessionGoingOffline extends HostSessionWithStatus {
  const HostSessionGoingOffline(super.status, {required this.since});

  final DateTime since;

  @override
  List<Object?> get props => [...super.props, since];
}

/// The online session ended (by the host or by the server).
final class HostSessionSessionEnded extends HostSessionWithStatus {
  const HostSessionSessionEnded(
    super.status, {
    required this.duration,
    required this.reason,
  });

  final Duration duration;
  final SessionEndReason reason;

  @override
  List<Object?> get props => [...super.props, duration, reason];
}
