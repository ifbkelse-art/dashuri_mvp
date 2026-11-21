import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/call_credentials.dart';
import '../../domain/entities/call_event.dart';
import '../../domain/entities/call_session.dart';

CallSession callSessionFromJson(JsonMap json) => CallSession(
  callId: json['call_id']! as String,
  role: CallRole.values.byName(json['role']! as String),
  peerUserId: json['peer_user_id']! as String,
  phase: CallPhase.values.byName(json['phase']! as String),
  ratePerMinute: json['rate_per_minute']! as int,
  billedSeconds: json['billed_seconds']! as int,
  diamondsCharged: json['diamonds_charged']! as int,
  isFreeCall: json['is_free_call']! as bool,
  endReason: json['end_reason'] as String?,
);

CallCredentials callCredentialsFromJson(JsonMap json) => CallCredentials(
  provider: json['provider']! as String,
  providerCallId: json['provider_call_id']! as String,
  userToken: json['user_token']! as String,
  expiresAt: DateTime.parse(json['expires_at']! as String),
);

/// Maps a realtime event; unknown types return null and are ignored.
CallEvent? callEventFromRealtime(RealtimeEvent e) => switch (e.type) {
  'call.updated' => CallUpdated(callSessionFromJson(e.payload)),
  'call.low_balance' => CallLowBalance(e.payload['seconds_remaining']! as int),
  _ => null,
};
