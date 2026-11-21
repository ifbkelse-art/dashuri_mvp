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
