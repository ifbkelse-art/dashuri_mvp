part of 'call_bloc.dart';

enum CallUiStatus {
  idle,
  requesting,

  /// Receiver side: the call is ringing on this device (V16).
  incoming,
  ringing,
  connecting,
  active,
  paused,
  ending,
  ended,
  failed,
}

final class CallState extends Equatable {
  const CallState({
    this.status = CallUiStatus.idle,
    this.session,
    this.mediaJoined = false,
    this.reconnecting = false,
    this.lowBalanceSecondsRemaining,
    this.failure,
    this.microphoneOn = true,
    this.cameraOn = true,
    this.requestedEndReason,
    this.endedByModeration = false,
  });

  final CallUiStatus status;

  /// Latest server view, including billed seconds and Diamonds charged.
  final CallSession? session;
  final bool mediaJoined;
  final bool reconnecting;

  /// Set when the server warns the balance is nearly used up (S6: 30 s warning).
  final int? lowBalanceSecondsRemaining;
  final Failure? failure;
  final bool microphoneOn;
  final bool cameraOn;

  /// The reason this device sent to `/end` (e.g. `report`), if it ended the call.
  final String? requestedEndReason;

  /// The server's safety check ended the call (`call.moderation_ended`).
  final bool endedByModeration;

  CallState copyWith({
    CallUiStatus? status,
    CallSession? session,
    bool? mediaJoined,
    bool? reconnecting,
    int? lowBalanceSecondsRemaining,
    Failure? failure,
    bool? microphoneOn,
    bool? cameraOn,
    String? requestedEndReason,
    bool? endedByModeration,
  }) => CallState(
    status: status ?? this.status,
    session: session ?? this.session,
    mediaJoined: mediaJoined ?? this.mediaJoined,
    reconnecting: reconnecting ?? this.reconnecting,
    lowBalanceSecondsRemaining:
        lowBalanceSecondsRemaining ?? this.lowBalanceSecondsRemaining,
    failure: failure,
    microphoneOn: microphoneOn ?? this.microphoneOn,
    cameraOn: cameraOn ?? this.cameraOn,
    requestedEndReason: requestedEndReason ?? this.requestedEndReason,
    endedByModeration: endedByModeration ?? this.endedByModeration,
  );

  @override
  List<Object?> get props => [
    status,
    session,
    mediaJoined,
    reconnecting,
    lowBalanceSecondsRemaining,
    failure,
    microphoneOn,
    cameraOn,
    requestedEndReason,
    endedByModeration,
  ];
}
