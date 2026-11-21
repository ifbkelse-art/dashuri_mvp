import 'package:equatable/equatable.dart';

final class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.peerUserId,
    required this.peerDisplayName,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.updatedAt,
  });

  final String id;
  final String peerUserId;
  final String peerDisplayName;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    peerUserId,
    peerDisplayName,
    lastMessagePreview,
    unreadCount,
    updatedAt,
  ];
}
