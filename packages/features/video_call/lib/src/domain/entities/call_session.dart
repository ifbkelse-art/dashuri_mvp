import 'package:equatable/equatable.dart';

enum CallRole { caller, receiver }

/// Server-owned call lifecycle (mirrors the backend state machine).
enum CallPhase {
  requested,
  ringing,
  accepted,
  connecting,
  active,
  paused,
  ending,
  ended,
  declined,
  missed,
  failed,
}

/// A call as reported by the server. Billing numbers are the server's.
/// The client may show them, never compute or submit them.
final class CallSession extends Equatable {
  const CallSession({
    required this.callId,
    required this.role,
    required this.peerUserId,
    required this.phase,
    required this.ratePerMinute,
    required this.billedSeconds,
    required this.diamondsCharged,
    required this.isFreeCall,
    required this.endReason,
  });

  final String callId;
  final CallRole role;
  final String peerUserId;
  final CallPhase phase;

  /// Diamonds per minute, fixed when the call was requested.
  final int ratePerMinute;
  final int billedSeconds;
  final int diamondsCharged;
  final bool isFreeCall;
  final String? endReason;

  @override
  List<Object?> get props => [
    callId,
    role,
    peerUserId,
    phase,
    ratePerMinute,
    billedSeconds,
    diamondsCharged,
    isFreeCall,
    endReason,
  ];
}
