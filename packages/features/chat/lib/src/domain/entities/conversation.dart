import 'package:equatable/equatable.dart';

import 'chat_message.dart';

final class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.peerUserId,
    required this.peerDisplayName,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.updatedAt,
    this.peerPhotoUrl,
    this.lastMessage,
  });

  final String id;
  final String peerUserId;
  final String peerDisplayName;
  final String? peerPhotoUrl;
  final String? lastMessagePreview;

  /// Full last message (MVP contract); lets the inbox show "You: …".
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    peerUserId,
    peerDisplayName,
    peerPhotoUrl,
    lastMessagePreview,
    lastMessage,
    unreadCount,
    updatedAt,
  ];
}
