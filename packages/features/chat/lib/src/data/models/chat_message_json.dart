import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/chat_message.dart';

/// Maps the API's snake_case JSON to [ChatMessage]. Keep in sync with api/openapi/dashuri.v1.yaml.
/// `context` and `read_by_peer` are optional (older servers omit them).
ChatMessage chatMessageFromJson(JsonMap json) => ChatMessage(
  id: json['id']! as String,
  conversationId: json['conversation_id']! as String,
  senderId: json['sender_id']! as String,
  body: json['body']! as String,
  sentAt: DateTime.parse(json['sent_at']! as String),
  context: json['context'] == 'call'
      ? MessageContext.call
      : MessageContext.chat,
  readByPeer: json['read_by_peer'] == true,
  isGift: json['kind'] == 'gift',
);
