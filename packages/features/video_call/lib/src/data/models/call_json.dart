import 'dart:convert';

import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/call_credentials.dart';
import '../../domain/entities/call_event.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/entities/pre_call_info.dart';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

int? _int(Object? v) => v is num ? v.toInt() : null;

CallPeer? _peer(Object? v) {
  if (v is! Map<String, Object?>) return null;
  final id = v['user_id'];
  if (id is! String) return null;
  return CallPeer(
    userId: id,
    displayName: (v['display_name'] as String?) ?? '',
    photoUrl: v['photo_url'] as String?,
  );
}

/// Maps the API's `CallSession` (contract 2.5 additions are optional).
CallSession callSessionFromJson(JsonMap json) => CallSession(
  callId: json['call_id']! as String,
  role: CallRole.values.byName(json['role']! as String),
  peerUserId: json['peer_user_id']! as String,
  phase: CallPhase.values.byName(json['phase']! as String),
  ratePerMinute: (json['rate_per_minute']! as num).toInt(),
  billedSeconds: (json['billed_seconds']! as num).toInt(),
  diamondsCharged: (json['diamonds_charged']! as num).toInt(),
  isFreeCall: json['is_free_call']! as bool,
  endReason: json['end_reason'] as String?,
  peer: _peer(json['peer']),
  startedAt: _date(json['started_at']),
  moderationWindowEndsAt: _date(json['moderation_window_ends_at']),
  beansEarned: _int(json['beans_earned']),
);

CallCredentials callCredentialsFromJson(JsonMap json) => CallCredentials(
  provider: json['provider']! as String,
  providerCallId: json['provider_call_id']! as String,
  userToken: json['user_token']! as String,
  expiresAt: DateTime.parse(json['expires_at']! as String),
  apiKey: json['api_key'] as String?,
  providerUserId: json['user_id'] as String?,
);

/// Maps a realtime event; unknown types return null and are ignored.
CallEvent? callEventFromRealtime(RealtimeEvent e) => switch (e.type) {
  'call.updated' => CallUpdated(callSessionFromJson(e.payload)),
  'call.low_balance' => CallLowBalance(
    (e.payload['seconds_remaining']! as num).toInt(),
  ),
  'call.moderation_ended' => const CallModerationEnded(),
  _ => null,
};

/// Combines GET /v1/discovery/hosts/{id}, GET /v1/wallet and
/// GET /v1/purchases/packages into the pre-call view.
PreCallInfo preCallInfoFromJson({
  required JsonMap host,
  required JsonMap wallet,
  JsonMap? packages,
}) => PreCallInfo(
  hostUserId: host['user_id']! as String,
  hostName: host['display_name']! as String,
  hostPhotoUrl: host['photo_url'] as String?,
  hostAge: _int(host['age']),
  ratePerMinute: (host['rate_per_minute']! as num).toInt(),
  availability: host['availability']! as String,
  availableDiamonds: (wallet['available_diamonds']! as num).toInt(),
  approxPaisePerDiamondMilli: _int(packages?['approx_paise_per_diamond_milli']),
);

/// Reads the `user_id` claim of a Stream user token (JWT) without
/// verifying it (the provider verifies). Returns null if malformed.
String? userIdFromJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload);
    if (map is Map<String, Object?>) {
      final id = map['user_id'] ?? map['sub'];
      return id is String ? id : null;
    }
  } on FormatException {
    return null;
  }
  return null;
}
