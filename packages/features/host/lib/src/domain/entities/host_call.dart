import 'package:equatable/equatable.dart';

/// One row of GET /v1/calls/history (contract 2.5), seen from the host side.
final class HostCall extends Equatable {
  const HostCall({
    required this.callId,
    required this.role,
    required this.peerUserId,
    required this.peerName,
    required this.peerPhotoUrl,
    required this.phase,
    required this.billedSeconds,
    required this.isFreeCall,
    required this.startedAt,
    required this.beansEarned,
    required this.endReason,
  });

  final String callId;
  final String role;
  final String peerUserId;
  final String? peerName;
  final String? peerPhotoUrl;
  final String phase;
  final int billedSeconds;
  final bool isFreeCall;

  /// Connected time, or the request time when the server sends `created_at`.
  final DateTime? startedAt;

  /// Beans credited to the host, when the server includes it.
  final int? beansEarned;
  final String? endReason;

  bool get isMissed =>
      phase == 'missed' || phase == 'declined' || phase == 'failed';
  bool get isPaid => !isFreeCall && !isMissed && billedSeconds > 0;

  @override
  List<Object?> get props => [
    callId,
    role,
    peerUserId,
    peerName,
    peerPhotoUrl,
    phase,
    billedSeconds,
    isFreeCall,
    startedAt,
    beansEarned,
    endReason,
  ];
}
