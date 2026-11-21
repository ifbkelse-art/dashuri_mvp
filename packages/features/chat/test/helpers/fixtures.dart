import 'package:feature_chat/feature_chat.dart';

final t0 = DateTime.utc(2026, 11, 21, 15);

ChatMessage msg(
  String id, {
  String sender = 'peer',
  int minute = 0,
  String? body,
}) => ChatMessage(
  id: id,
  conversationId: 'c1',
  senderId: sender,
  body: body ?? 'message $id',
  sentAt: t0.add(Duration(minutes: minute)),
);

final meera = Conversation(
  id: 'c1',
  peerUserId: 'peer',
  peerDisplayName: 'Meera',
  lastMessagePreview: 'It was lovely talking to you!',
  unreadCount: 2,
  updatedAt: t0,
);
final kavya = Conversation(
  id: 'c2',
  peerUserId: 'peer2',
  peerDisplayName: 'Kavya',
  lastMessagePreview: null,
  lastMessage: msg('m9', sender: 'me', body: 'Thank you'),
  unreadCount: 0,
  updatedAt: t0,
);
