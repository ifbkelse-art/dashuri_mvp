import 'package:equatable/equatable.dart';

final class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.sentAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime sentAt;

  @override
  List<Object?> get props => [id, conversationId, senderId, body, sentAt];
}
