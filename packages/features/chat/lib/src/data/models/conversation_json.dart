import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/conversation.dart';
import 'chat_message_json.dart';

/// Maps the API's snake_case JSON to [Conversation]. Accepts the MVP shape
/// (`peer {user_id, display_name, photo_url}`, `last_message`) and the
/// original flat fields (`peer_user_id`, `peer_display_name`, `last_message_preview`).
Conversation conversationFromJson(JsonMap json) {
  final peer = json['peer'] is JsonMap ? json['peer']! as JsonMap : null;
  final last = json['last_message'] is JsonMap
      ? chatMessageFromJson(json['last_message']! as JsonMap)
      : null;
  return Conversation(
    id: json['id']! as String,
    peerUserId: (peer?['user_id'] ?? json['peer_user_id'])! as String,
    peerDisplayName:
        (peer?['display_name'] ?? json['peer_display_name']) as String? ?? '',
    peerPhotoUrl: (peer?['photo_url'] ?? json['peer_photo_url']) as String?,
    peerIsVerified: peer?['is_verified'] == true,
    lastMessagePreview: json['last_message_preview'] as String? ?? last?.body,
    lastMessage: last,
    unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(
      (json['updated_at'] ?? last?.sentAt.toIso8601String())! as String,
    ),
  );
}
