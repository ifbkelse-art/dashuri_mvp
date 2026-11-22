import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/messaging_privacy.dart';
import '../models/chat_message_json.dart';
import '../models/conversation_json.dart';
import '../models/messaging_privacy_json.dart';

/// HTTP access to the chat endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
// Not final: repository tests mock it.
class ChatRemoteDataSource {
  const ChatRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<Page<Conversation>>> listConversations({
    required PageRequest page,
  }) => _api.get(
    '/v1/conversations',
    decode: pageDecoder(conversationFromJson),
    query: page.toQuery(),
  );

  Future<Result<Conversation>> startConversation({
    required String peerUserId,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/conversations',
    decode: objectDecoder(conversationFromJson),
    body: {'peer_user_id': peerUserId},
    idempotencyKey: idempotencyKey,
  );

  Future<Result<Page<ChatMessage>>> listMessages({
    required String conversationId,
    required PageRequest page,
  }) => _api.get(
    '/v1/conversations/$conversationId/messages',
    decode: pageDecoder(chatMessageFromJson),
    query: page.toQuery(),
  );

  /// With [callId] the message is sent from the in-call panel: it carries
  /// `context: call`, the call and a `client_message_id` (the idempotency
  /// key) for server-side duplicate protection. Without it the body is the
  /// original `{body}` so older servers keep working.
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    required IdempotencyKey idempotencyKey,
    String? callId,
  }) => _api.post(
    '/v1/conversations/$conversationId/messages',
    decode: objectDecoder(chatMessageFromJson),
    body: {
      'body': body,
      if (callId != null) ...{
        'context': 'call',
        'call_id': callId,
        'client_message_id': idempotencyKey.value,
      },
    },
    idempotencyKey: idempotencyKey,
  );

  Future<Result<void>> markRead(String conversationId) =>
      _api.post<void>('/v1/conversations/$conversationId/read', decode: (_) {});

  Future<Result<MessagingPrivacy>> getMessagingPrivacy() => _api.get(
    '/v1/me/messaging-privacy',
    decode: objectDecoder(messagingPrivacyFromJson),
  );

  Future<Result<MessagingPrivacy>> updateMessagingPrivacy({
    required String whoCanMessage,
  }) => _api.put(
    '/v1/me/messaging-privacy',
    decode: objectDecoder(messagingPrivacyFromJson),
    body: {'who_can_message': whoCanMessage},
  );
}
