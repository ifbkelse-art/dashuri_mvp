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
  failed;

  /// Terminal phases: nothing more will happen on this call.
  bool get isTerminal => switch (this) {
    ended || declined || missed || failed => true,
    _ => false,
  };
}

/// The other participant as the server describes them (contract 2.5).
final class CallPeer extends Equatable {
  const CallPeer({
    required this.userId,
    required this.displayName,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;

  @override
  List<Object?> get props => [userId, displayName, photoUrl];
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
    this.peer,
    this.startedAt,
    this.moderationWindowEndsAt,
    this.beansEarned,
    this.createdAt,
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

  /// Display details of the other participant (null on older servers).
  final CallPeer? peer;

  /// When the server saw both participants live (billing start).
  final DateTime? startedAt;

  /// End of the automated safety-check window (S7, D-09).
  final DateTime? moderationWindowEndsAt;

  /// Beans credited to the host for this call, when the server reports it.
  final int? beansEarned;

  /// When the call was requested.
  final DateTime? createdAt;

  String get peerName => peer?.displayName ?? '';

  /// This snapshot with [peer] filled from [previous] when the server
  /// omitted it (e.g. `call:<id>` events seen from the receiver side).
  CallSession withPeerFrom(CallSession? previous) =>
      peer != null || previous?.peer == null
      ? this
      : copyWith(peer: previous!.peer);

  CallSession copyWith({CallPeer? peer}) => CallSession(
    callId: callId,
    role: role,
    peerUserId: peerUserId,
    phase: phase,
    ratePerMinute: ratePerMinute,
    billedSeconds: billedSeconds,
    diamondsCharged: diamondsCharged,
    isFreeCall: isFreeCall,
    endReason: endReason,
    peer: peer ?? this.peer,
    startedAt: startedAt,
    moderationWindowEndsAt: moderationWindowEndsAt,
    beansEarned: beansEarned,
    createdAt: createdAt,
  );

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
    peer,
    startedAt,
    moderationWindowEndsAt,
    beansEarned,
    createdAt,
  ];
}
