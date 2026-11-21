import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_call.dart';

/// Maps a `CallSession` row from GET /v1/calls/history (contract 2.5).
/// `peer`, `started_at`, `created_at` and `beans_earned` are optional so the
/// history renders against servers that do not send them yet.
HostCall hostCallFromJson(JsonMap json) {
  final peer = json['peer'] as JsonMap?;
  final started = (json['started_at'] ?? json['created_at']) as String?;
  return HostCall(
    callId: json['call_id']! as String,
    role: json['role']! as String,
    peerUserId:
        (json['peer_user_id'] as String?) ?? (peer?['user_id']! as String),
    peerName: peer?['display_name'] as String?,
    peerPhotoUrl: peer?['photo_url'] as String?,
    phase: json['phase']! as String,
    billedSeconds: json['billed_seconds']! as int,
    isFreeCall: json['is_free_call']! as bool,
    startedAt: started == null ? null : DateTime.parse(started),
    beansEarned: json['beans_earned'] as int?,
    endReason: json['end_reason'] as String?,
  );
}
