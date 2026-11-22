import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/messaging_privacy.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

/// Default [ChatRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(
    this._remote, {
    required RealtimeGateway realtime,
    required SessionGateway session,
  }) : _realtime = realtime,
       _session = session;

  final ChatRemoteDataSource _remote;
  final RealtimeGateway _realtime;
  final SessionGateway _session;

  @override
  Future<Result<void>> markRead(String conversationId) =>
      _remote.markRead(conversationId);

  @override
  String? currentUserId() => _session.currentSession?.userId;

  @override
  Stream<String> chatHints() => _hints('chat.message');

  @override
  Stream<String> readHints() => _hints('chat.read');

  Stream<String> _hints(String type) {
    final userId = currentUserId();
    if (userId == null) return const Stream.empty();
    return _realtime
        .subscribe('user:$userId')
        .where((e) => e.type == type)
        .map((e) => e.payload['conversation_id'])
        .where((id) => id is String)
        .cast<String>();
  }

  @override
  Future<Result<Page<Conversation>>> listConversations({
    required PageRequest page,
  }) => _remote.listConversations(page: page);

  @override
  Future<Result<Conversation>> startConversation({
    required String peerUserId,
    required IdempotencyKey idempotencyKey,
  }) => _remote.startConversation(
    peerUserId: peerUserId,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<Page<ChatMessage>>> listMessages({
    required String conversationId,
    required PageRequest page,
  }) => _remote.listMessages(conversationId: conversationId, page: page);

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    required IdempotencyKey idempotencyKey,
    String? callId,
  }) => _remote.sendMessage(
    conversationId: conversationId,
    body: body,
    idempotencyKey: idempotencyKey,
    callId: callId,
  );

  @override
  Future<Result<MessagingPrivacy>> getMessagingPrivacy() =>
      _remote.getMessagingPrivacy();

  @override
  Future<Result<MessagingPrivacy>> updateMessagingPrivacy({
    required String whoCanMessage,
  }) => _remote.updateMessagingPrivacy(whoCanMessage: whoCanMessage);
}
