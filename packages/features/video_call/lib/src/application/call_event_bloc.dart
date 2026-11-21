part of 'call_bloc.dart';

sealed class CallBlocEvent extends Equatable {
  const CallBlocEvent();

  @override
  List<Object?> get props => [];
}

/// Customer taps "Call" on a host.
final class CallOutgoingRequested extends CallBlocEvent {
  const CallOutgoingRequested(this.hostUserId);

  final String hostUserId;

  @override
  List<Object?> get props => [hostUserId];
}

/// Host accepts an incoming call (from the incoming-call screen or notification).
final class CallIncomingAccepted extends CallBlocEvent {
  const CallIncomingAccepted(this.callId);

  final String callId;

  @override
  List<Object?> get props => [callId];
}

final class CallIncomingDeclined extends CallBlocEvent {
  const CallIncomingDeclined(this.callId);

  final String callId;

  @override
  List<Object?> get props => [callId];
}

/// Either party hangs up. [reason]: `hangup`, `report`, `low_balance_ack`, …
final class CallEndRequested extends CallBlocEvent {
  const CallEndRequested({this.reason = 'hangup'});

  final String reason;

  @override
  List<Object?> get props => [reason];
}

final class CallServerEventReceived extends CallBlocEvent {
  const CallServerEventReceived(this.event);

  final CallEvent event;

  @override
  List<Object?> get props => [event];
}

final class CallMediaEventReceived extends CallBlocEvent {
  const CallMediaEventReceived(this.event);

  final MediaEvent event;

  @override
  List<Object?> get props => [event];
}

/// Opens the call screen for an existing call: the caller after the
/// pre-call request or a free-call match, or the host for an incoming ring
/// ([incoming] = true).
final class CallAttachRequested extends CallBlocEvent {
  const CallAttachRequested(this.callId, {this.incoming = false});

  final String callId;
  final bool incoming;

  @override
  List<Object?> get props => [callId, incoming];
}

final class CallMicrophoneToggled extends CallBlocEvent {
  const CallMicrophoneToggled();
}

final class CallCameraToggled extends CallBlocEvent {
  const CallCameraToggled();
}

final class CallCameraFlipped extends CallBlocEvent {
  const CallCameraFlipped();
}

/// Periodic re-fetch while waiting on the other side (realtime is a hint).
final class CallRefreshTicked extends CallBlocEvent {
  const CallRefreshTicked();
}
