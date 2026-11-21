import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/conversation.dart';

/// Maps the API's snake_case JSON to [Conversation]. Keep in sync with api/openapi/dashuri.v1.yaml.
Conversation conversationFromJson(JsonMap json) => Conversation(
  id: json['id']! as String,
  peerUserId: json['peer_user_id']! as String,
  peerDisplayName: json['peer_display_name']! as String,
  lastMessagePreview: json['last_message_preview'] as String?,
  unreadCount: json['unread_count']! as int,
  updatedAt: DateTime.parse(json['updated_at']! as String),
);
