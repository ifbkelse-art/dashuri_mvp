part of 'call_bloc.dart';

enum CallUiStatus {
  idle,
  requesting,
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
  });

  final CallUiStatus status;

  /// Latest server view, including billed seconds and Diamonds charged.
  final CallSession? session;
  final bool mediaJoined;
  final bool reconnecting;

  /// Set when the server warns the balance is nearly used up (S6: 30 s warning).
  final int? lowBalanceSecondsRemaining;
  final Failure? failure;

  CallState copyWith({
    CallUiStatus? status,
    CallSession? session,
    bool? mediaJoined,
    bool? reconnecting,
    int? lowBalanceSecondsRemaining,
    Failure? failure,
  }) => CallState(
    status: status ?? this.status,
    session: session ?? this.session,
    mediaJoined: mediaJoined ?? this.mediaJoined,
    reconnecting: reconnecting ?? this.reconnecting,
    lowBalanceSecondsRemaining:
        lowBalanceSecondsRemaining ?? this.lowBalanceSecondsRemaining,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    status,
    session,
    mediaJoined,
    reconnecting,
    lowBalanceSecondsRemaining,
    failure,
  ];
}
