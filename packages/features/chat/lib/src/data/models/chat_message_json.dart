import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/chat_message.dart';

/// Maps the API's snake_case JSON to [ChatMessage]. Keep in sync with api/openapi/dashuri.v1.yaml.
ChatMessage chatMessageFromJson(JsonMap json) => ChatMessage(
  id: json['id']! as String,
  conversationId: json['conversation_id']! as String,
  senderId: json['sender_id']! as String,
  body: json['body']! as String,
  sentAt: DateTime.parse(json['sent_at']! as String),
);
