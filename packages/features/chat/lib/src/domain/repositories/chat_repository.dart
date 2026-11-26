import 'package:dashuri_core/dashuri_core.dart';

import '../entities/chat_message.dart';
import '../entities/conversation.dart';
import '../entities/messaging_privacy.dart';

/// Contract for chat data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class ChatRepository {
  Future<Result<Page<Conversation>>> listConversations({
    required PageRequest page,
  });

  Future<Result<Conversation>> startConversation({
    required String peerUserId,
    required IdempotencyKey idempotencyKey,
  });

  /// Newest first. With [callId]: only that call's session chat; without:
  /// normal Chat (live calls' session messages are not included yet).
  Future<Result<Page<ChatMessage>>> listMessages({
    required String conversationId,
    required PageRequest page,
    String? callId,
  });

  /// [callId]: sent from the in-call panel of that call (same conversation).
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    required IdempotencyKey idempotencyKey,
    String? callId,
  });

  /// POST /v1/conversations/{id}/read
  Future<Result<void>> markRead(String conversationId);

  Future<Result<MessagingPrivacy>> getMessagingPrivacy();

  Future<Result<MessagingPrivacy>> updateMessagingPrivacy({
    required String whoCanMessage,
  });

  /// Signed-in user id (to tell own messages apart); null when signed out.
  String? currentUserId();

  /// Conversation ids from `chat.message` hints on `user:<id>`. Hints only:
  /// callers re-fetch from the API.
  Stream<String> chatHints();

  /// Conversation ids from `chat.read` hints (the peer read my messages).
  Stream<String> readHints();

  /// Messages carried inside `chat.message` hints (servers since
  /// 2026-11-23), so a new message shows without a second request. Hints
  /// without a message add nothing here; [chatHints] still fires for them.
  Stream<ChatHintMessage> chatHintMessages();
}
