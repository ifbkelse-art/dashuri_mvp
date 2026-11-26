import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_video_call/src/data/datasources/gift_remote_data_source.dart';
import 'package:feature_video_call/src/data/models/gift_json.dart';
import 'package:feature_video_call/src/data/repositories/gift_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Remote extends Mock implements GiftRemoteDataSource {}

final class _Realtime implements RealtimeGateway {
  // Closed by the test that uses it.
  // ignore: close_sinks
  final c = StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> subscribe(String channel) => c.stream;
}

const _event = <String, Object?>{
  'gift_transaction_id': 'g1',
  'gift_id': 'diamond_ring',
  'gift_name': 'Diamond Ring',
  'emoji': '💎',
  'tier': 'epic',
  'diamond_value': 25000,
  'sender': {'user_id': 'u1', 'display_name': 'Asha'},
  'recipient': {'user_id': 'h1', 'display_name': 'Meera'},
  'call_id': 'c1',
  'animation_asset': 'celebration/diamond_ring',
  'animation_duration_ms': 5000,
  'chat_message_id': 'm1',
  'sent_at': '2026-11-26T10:00:00Z',
};

void main() {
  test('catalogue JSON: sorted by sort order, unknown tier is common', () {
    final gifts = giftCatalogueFromJson({
      'items': [
        {
          'id': 'b',
          'name': 'B',
          'emoji': '🧸',
          'tier': 'new_tier',
          'sort_order': 20,
          'diamond_price': 5000,
        },
        {
          'id': 'a',
          'name': 'A',
          'emoji': '🌹',
          'tier': 'rare',
          'sort_order': 10,
          'diamond_price': 1500,
          'animation_duration_ms': 4000,
        },
      ],
      'updated_at': '2026-11-26T00:00:00Z',
    });
    expect(gifts.map((g) => g.id), ['a', 'b']);
    expect(gifts[0].tier, GiftTier.rare);
    expect(gifts[0].animationDuration, const Duration(seconds: 4));
    expect(gifts[1].tier, GiftTier.common);
    expect(gifts[1].animationDuration, const Duration(seconds: 5));
  });

  test('receipt and event JSON', () {
    final r = giftReceiptFromJson({
      'gift': _event,
      'available_diamonds': 75000,
      'replayed': true,
    });
    expect(r.availableDiamonds, 75000);
    expect(r.replayed, isTrue);
    expect(r.event.tier, GiftTier.epic);
    expect(r.event.senderName, 'Asha');
    expect(r.event.chatMessageId, 'm1');
    expect(r.event.sentAt, DateTime.utc(2026, 11, 26, 10));
  });

  test('send never puts a price in the request; key in the header', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    Object? body;
    String? path, key;
    server.listen((req) async {
      path = req.uri.path;
      key = req.headers.value('Idempotency-Key');
      body = jsonDecode(await utf8.decoder.bind(req).join());
      req.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'gift': _event,
            'available_diamonds': 1,
            'replayed': false,
          }),
        );
      await req.response.close();
    });
    final ds = GiftRemoteDataSource(
      ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        tokens: _Token(),
      ),
    );
    final k = IdempotencyKey.generate();
    final r = await ds.send('c1', 'rose', 'h1', k);
    expect(r, isA<Success<GiftReceipt>>());
    expect(body, {'gift_id': 'rose', 'recipient_user_id': 'h1'});
    expect(path, '/v1/calls/c1/gifts');
    expect(key, k.value);
  });

  test(
    'realtime: only call.gift of this call; malformed payloads dropped',
    () async {
      final rt = _Realtime();
      final repo = GiftRepositoryImpl(_Remote(), rt);
      final got = <String>[];
      final sub = repo
          .watchCallGifts('c1')
          .listen((e) => got.add(e.giftTransactionId));
      rt.c
        ..add(
          const RealtimeEvent(
            channel: 'call:c1',
            type: 'call.updated',
            payload: {},
          ),
        )
        ..add(
          const RealtimeEvent(
            channel: 'call:c1',
            type: 'call.gift',
            payload: {'nope': 1},
          ),
        )
        ..add(
          const RealtimeEvent(
            channel: 'call:c1',
            type: 'call.gift',
            payload: _event,
          ),
        )
        ..add(
          RealtimeEvent(
            channel: 'call:c1',
            type: 'call.gift',
            payload: Map.of(_event)..['call_id'] = 'other',
          ),
        );
      await Future<void>.delayed(Duration.zero);
      expect(got, ['g1']);
      await sub.cancel();
      await rt.c.close();
    },
  );
}

final class _Token implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => 't';
}
