import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_chat/src/data/datasources/chat_remote_data_source.dart';
import 'package:feature_chat/src/data/models/conversation_json.dart';
import 'package:feature_chat/src/data/repositories/chat_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Remote extends Mock implements ChatRemoteDataSource {}

class _Session extends Mock implements SessionGateway {}

class _Realtime implements RealtimeGateway {
  // ignore: close_sinks, closed by the tests that use it.
  final controller = StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> subscribe(String channel) {
    expect(channel, 'user:me');
    return controller.stream;
  }
}

void main() {
  test('maps the MVP conversation shape', () {
    final c = conversationFromJson({
      'id': 'c1',
      'peer': {
        'user_id': 'u2',
        'display_name': 'Meera',
        'photo_url': 'https://x/p.jpg',
      },
      'last_message': {
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u2',
        'body': 'Hi',
        'sent_at': '2026-11-21T10:00:00Z',
      },
      'unread_count': 3,
      'updated_at': '2026-11-21T10:00:00Z',
    });
    expect(c.peerUserId, 'u2');
    expect(c.peerPhotoUrl, 'https://x/p.jpg');
    expect(c.lastMessage!.body, 'Hi');
    expect(c.lastMessagePreview, 'Hi');
    expect(c.unreadCount, 3);
  });

  test('maps the original flat conversation shape', () {
    final c = conversationFromJson({
      'id': 'c1',
      'peer_user_id': 'u2',
      'peer_display_name': 'Meera',
      'last_message_preview': 'Hey',
      'unread_count': 0,
      'updated_at': '2026-11-21T10:00:00Z',
    });
    expect(c.peerDisplayName, 'Meera');
    expect(c.lastMessage, isNull);
    expect(c.lastMessagePreview, 'Hey');
  });

  test('chatHints listens on user:<id> and yields conversation ids', () async {
    final session = _Session();
    final realtime = _Realtime();
    when(
      () => session.currentSession,
    ).thenReturn(AuthSession(userId: 'me', expiresAt: DateTime.utc(2030)));
    final repo = ChatRepositoryImpl(
      _Remote(),
      realtime: realtime,
      session: session,
    );
    expect(repo.currentUserId(), 'me');
    final ids = <String>[];
    final sub = repo.chatHints().listen(ids.add);
    realtime.controller
      ..add(
        const RealtimeEvent(
          channel: 'user:me',
          type: 'wallet.updated',
          payload: {},
        ),
      )
      ..add(
        const RealtimeEvent(
          channel: 'user:me',
          type: 'chat.message',
          payload: {'conversation_id': 'c1'},
        ),
      )
      ..add(
        const RealtimeEvent(
          channel: 'user:me',
          type: 'chat.message',
          payload: {},
        ),
      );
    await Future<void>.delayed(Duration.zero);
    expect(ids, ['c1']);
    await sub.cancel();
    await realtime.controller.close();
  });

  test('markRead delegates to the API', () async {
    final remote = _Remote();
    when(
      () => remote.markRead('c1'),
    ).thenAnswer((_) async => const Success(null));
    final session = _Session();
    final repo = ChatRepositoryImpl(
      remote,
      realtime: _Realtime(),
      session: session,
    );
    expect(await repo.markRead('c1'), isA<Success<void>>());
  });
}
