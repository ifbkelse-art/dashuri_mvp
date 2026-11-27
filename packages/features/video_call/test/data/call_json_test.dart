import 'dart:convert';

import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_video_call/src/data/models/call_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = <String, Object?>{
    'call_id': 'c1',
    'role': 'caller',
    'peer_user_id': 'h1',
    'phase': 'active',
    'rate_per_minute': 2400,
    'billed_seconds': 65,
    'diamonds_charged': 2600,
    'is_free_call': false,
  };

  test('parses the base CallSession', () {
    final s = callSessionFromJson(base);
    expect(s.phase, CallPhase.active);
    expect(s.peer, isNull);
    expect(s.moderationWindowEndsAt, isNull);
  });

  test('parses contract 2.5 additions', () {
    final s = callSessionFromJson({
      ...base,
      'peer': {'user_id': 'h1', 'display_name': 'Ananya', 'photo_url': null},
      'started_at': '2026-11-21T10:00:00Z',
      'moderation_window_ends_at': '2026-11-21T10:03:00Z',
      'beans_earned': 1200,
    });
    expect(s.peerName, 'Ananya');
    expect(s.startedAt, DateTime.utc(2026, 11, 21, 10));
    expect(s.moderationWindowEndsAt, DateTime.utc(2026, 11, 21, 10, 3));
    expect(s.beansEarned, 1200);
  });

  test('gift Beans on the call (28 Nov): total plus the gift part', () {
    final s = callSessionFromJson({
      ...base,
      'beans_earned': 4035,
      'gift_beans_earned': 3898,
    });
    expect(s.beansEarned, 4035);
    expect(s.giftBeansEarned, 3898);
    expect(
      callSessionFromJson({...base, 'beans_earned': 137}).giftBeansEarned,
      isNull,
    );
  });

  test('peer Verified Host flag (2026-11-23), absent means false', () {
    final verified = callSessionFromJson({
      ...base,
      'peer': {'user_id': 'h1', 'display_name': 'A', 'is_verified': true},
    });
    expect(verified.peer!.isVerified, isTrue);
    final plain = callSessionFromJson({
      ...base,
      'peer': {'user_id': 'h1', 'display_name': 'A'},
    });
    expect(plain.peer!.isVerified, isFalse);
  });

  test('credentials with optional api key', () {
    final c = callCredentialsFromJson({
      'provider': 'stream',
      'provider_call_id': 'default:abc',
      'user_token': 'x.y.z',
      'expires_at': '2026-11-21T10:00:00Z',
      'api_key': 'k',
    });
    expect(c.apiKey, 'k');
    expect(c.providerUserId, isNull);
  });

  test('call:<id> events are re-read from the receiver side', () {
    final callerView = {
      ...base,
      'peer': {'user_id': 'h1', 'display_name': 'Host'},
      'caller_user_id': 'cust',
      'receiver_user_id': 'h1',
    };
    final mine = callSessionForUser(callerView, 'h1');
    expect(mine.role, CallRole.receiver);
    expect(mine.peerUserId, 'cust');
    expect(mine.peer, isNull);
    final asCaller = callSessionForUser(callerView, 'cust');
    expect(asCaller.role, CallRole.caller);
    expect(asCaller.peerName, 'Host');
    final keep = mine.withPeerFrom(
      callSessionFromJson({
        ...base,
        'peer': {'user_id': 'cust', 'display_name': 'Arjun'},
      }),
    );
    expect(keep.peerName, 'Arjun');
  });

  test('credentials accept token and call_type', () {
    final c = callCredentialsFromJson({
      'provider': 'stream',
      'provider_call_id': 'abc',
      'token': 'x.y.z',
      'expires_at': '2026-11-21T10:00:00Z',
      'api_key': 'k',
      'call_type': 'default',
    });
    expect(c.userToken, 'x.y.z');
    expect(c.callType, 'default');
  });

  test('realtime events map, unknown ones are ignored', () {
    RealtimeEvent ev(String type, Map<String, Object?> p) =>
        RealtimeEvent(channel: 'call:c1', type: type, payload: p);
    expect(
      callEventFromRealtime(ev('call.low_balance', {'seconds_remaining': 30})),
      const CallLowBalance(30),
    );
    expect(
      callEventFromRealtime(ev('call.moderation_ended', {})),
      const CallModerationEnded(),
    );
    expect(callEventFromRealtime(ev('call.updated', base)), isA<CallUpdated>());
    expect(callEventFromRealtime(ev('other', {})), isNull);
  });

  test('pre-call info combines host, wallet and packages', () {
    final info = preCallInfoFromJson(
      host: {
        'user_id': 'h1',
        'display_name': 'Ananya',
        'rate_per_minute': 2400,
        'availability': 'available',
        'age': 24,
      },
      wallet: {'available_diamonds': 100},
      packages: {'approx_paise_per_diamond_milli': 2200},
    );
    expect(info.hostAge, 24);
    expect(info.hasMinimumBalance, isFalse);
    expect(info.approxPaisePerMinute, 5280);
  });

  test('reads user_id from a JWT payload', () {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'user_id': 'u1'})))
        .replaceAll('=', '');
    expect(userIdFromJwt('h.$payload.s'), 'u1');
    expect(userIdFromJwt('bad'), isNull);
  });
}
