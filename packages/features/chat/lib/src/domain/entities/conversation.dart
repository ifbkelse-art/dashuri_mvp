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
    this.peerIsVerified = false,
  });

  final String id;
  final String peerUserId;
  final String peerDisplayName;
  final String? peerPhotoUrl;

  /// The peer is an ACTIVE Verified Host (badge only).
  final bool peerIsVerified;
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
    peerIsVerified,
    lastMessagePreview,
    lastMessage,
    unreadCount,
    updatedAt,
  ];
}
