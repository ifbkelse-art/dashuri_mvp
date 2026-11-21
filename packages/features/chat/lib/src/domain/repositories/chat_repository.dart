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

  Future<Result<Page<ChatMessage>>> listMessages({
    required String conversationId,
    required PageRequest page,
  });

  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<MessagingPrivacy>> getMessagingPrivacy();

  Future<Result<MessagingPrivacy>> updateMessagingPrivacy({
    required String whoCanMessage,
  });
}
