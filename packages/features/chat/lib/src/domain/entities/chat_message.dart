import 'package:equatable/equatable.dart';

/// Where a message was sent from. Metadata only: inbox and in-call messages
/// are the same kind of message in the pair's one conversation.
enum MessageContext {
  /// Sent from the inbox conversation.
  chat,

  /// Sent from the in-call chat panel during a video call.
  call,
}

final class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    this.context = MessageContext.chat,
    this.readByPeer = false,
    this.isGift = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final MessageContext context;

  /// For the signed-in user's own messages: the other person has read it.
  final bool readByPeer;

  /// A server-written gift line ("🌹 Asha sent Rose to Meera."), 2026-11-26.
  final bool isGift;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    body,
    sentAt,
    context,
    readByPeer,
    isGift,
  ];
}

/// A message delivered inside a `chat.message` realtime hint, with the call
/// it was sent during (in-call messages only).
final class ChatHintMessage extends Equatable {
  const ChatHintMessage(this.message, {this.callId});

  final ChatMessage message;
  final String? callId;

  @override
  List<Object?> get props => [message, callId];
}
