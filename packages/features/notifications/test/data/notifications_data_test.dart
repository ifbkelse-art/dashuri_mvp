import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/src/data/datasources/notifications_realtime_source.dart';
import 'package:feature_notifications/src/data/datasources/notifications_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_api.dart';
import '../helpers/mocks.dart';

void main() {
  group('NotificationsRemoteDataSource', () {
    late FakeApi api;
    setUp(() async => api = await FakeApi.start());
    tearDown(() => api.close());

    test('GET /v1/notifications pages', () async {
      api.response = {
        'items': [
          {
            'id': 'n1',
            'kind': 'chat.message',
            'title': 'Meera sent you a message',
            'body': 'Hi',
            'created_at': '2026-11-21T10:00:00Z',
            'read_at': null,
          },
        ],
        'next_cursor': null,
      };
      final r = await NotificationsRemoteDataSource(
        api.client,
      ).listInbox(page: const PageRequest());
      final page = (r as Success<Page<InboxItem>>).value;
      expect(page.items.single.readAt, isNull);
      expect(page.hasMore, isFalse);
      expect(api.last.uri.path, '/v1/notifications');
    });

    test('POST /v1/notifications/{id}/read', () async {
      api.status = 204;
      final r = await NotificationsRemoteDataSource(
        api.client,
      ).markRead(notificationId: 'n1');
      expect(r.isSuccess, isTrue);
      expect(api.last.method, 'POST');
      expect(api.last.uri.path, '/v1/notifications/n1/read');
    });
  });

  group('NotificationsRealtimeSource', () {
    test(
      'subscribes to user:<id> and keeps notification.created only',
      () async {
        final realtime = MockRealtimeGateway();
        final session = MockSessionGateway();
        when(
          () => session.currentSession,
        ).thenReturn(AuthSession(userId: 'u1', expiresAt: DateTime.utc(2030)));
        when(() => realtime.subscribe('user:u1')).thenAnswer(
          (_) => Stream.fromIterable(const [
            RealtimeEvent(
              channel: 'user:u1',
              type: 'wallet.updated',
              payload: {},
            ),
            RealtimeEvent(
              channel: 'user:u1',
              type: 'notification.created',
              payload: {},
            ),
          ]),
        );
        final events = await NotificationsRealtimeSource(
          realtime,
          session,
        ).watch().toList();
        expect(events, hasLength(1));
      },
    );

    test('no session, no subscription', () async {
      final realtime = MockRealtimeGateway();
      final session = MockSessionGateway();
      when(() => session.currentSession).thenReturn(null);
      expect(
        await NotificationsRealtimeSource(realtime, session).watch().toList(),
        isEmpty,
      );
      verifyNever(() => realtime.subscribe(any()));
    });
  });
}
