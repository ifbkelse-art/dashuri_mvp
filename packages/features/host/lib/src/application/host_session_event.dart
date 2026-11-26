part of 'host_session_bloc.dart';

sealed class HostSessionEvent extends Equatable {
  const HostSessionEvent();

  @override
  List<Object?> get props => [];
}

/// Opened Host Home. [activate]: the host tapped Go online (start the
/// activation flow); [after]: Host Home was reopened after a call.
final class HostSessionStarted extends HostSessionEvent {
  const HostSessionStarted({
    this.activate = false,
    this.after = CallNotice.none,
  });

  final bool activate;
  final CallNotice after;

  @override
  List<Object?> get props => [activate, after];
}

final class HostSessionGoOnlinePressed extends HostSessionEvent {
  const HostSessionGoOnlinePressed();
}

/// The arrival-photo step is done (captured or skipped): go online.
final class HostSessionActivationProceed extends HostSessionEvent {
  const HostSessionActivationProceed();
}

final class HostSessionActivationCancelled extends HostSessionEvent {
  const HostSessionActivationCancelled();
}

final class HostSessionGoOfflinePressed extends HostSessionEvent {
  const HostSessionGoOfflinePressed();
}

final class HostSessionIncomingCall extends HostSessionEvent {
  const HostSessionIncomingCall(this.callId);

  final String callId;

  @override
  List<Object?> get props => [callId];
}

final class HostSessionNetworkChanged extends HostSessionEvent {
  const HostSessionNetworkChanged({
    required this.healthy,
    required this.failures,
  });

  final bool healthy;
  final int failures;

  @override
  List<Object?> get props => [healthy, failures];
}

final class HostSessionHeartbeatRefused extends HostSessionEvent {
  const HostSessionHeartbeatRefused(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class HostSessionRetryPressed extends HostSessionEvent {
  const HostSessionRetryPressed();
}
