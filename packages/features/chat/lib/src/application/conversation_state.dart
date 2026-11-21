part of 'conversation_cubit.dart';

enum ConversationStatus {
  /// Creating the conversation (route id `new`).
  starting,
  loading,
  ready,

  /// CH04: the peer accepts messages only from past call partners.
  restricted,
  failed,
}

enum BubbleStatus { sent, sending, failed, rejected }

/// One row of the message list: a server message or a local optimistic one.
final class ChatBubble extends Equatable {
  const ChatBubble({
    required this.localId,
    required this.body,
    required this.sentAt,
    required this.mine,
    this.status = BubbleStatus.sent,
    this.serverId,
  });

  factory ChatBubble.fromMessage(ChatMessage m, {required String? myUserId}) =>
      ChatBubble(
        localId: m.id,
        serverId: m.id,
        body: m.body,
        sentAt: m.sentAt,
        mine: m.senderId == myUserId,
      );

  /// Server id for sent messages; the idempotency key for local ones.
  final String localId;
  final String? serverId;
  final String body;
  final DateTime sentAt;
  final bool mine;
  final BubbleStatus status;

  ChatBubble withStatus(BubbleStatus s) => ChatBubble(
    localId: localId,
    serverId: serverId,
    body: body,
    sentAt: sentAt,
    mine: mine,
    status: s,
  );

  @override
  List<Object?> get props => [localId, serverId, body, sentAt, mine, status];
}

final class ConversationState extends Equatable {
  const ConversationState({
    required this.status,
    this.conversationId,
    this.peerUserId,
    this.peerName,
    this.peerPhotoUrl,
    this.bubbles = const [],
    this.olderCursor,
    this.loadingOlder = false,
    this.failure,
    this.filterNotice = false,
    this.restoredDraft,
    this.sendFailure,
  });

  final ConversationStatus status;

  /// Real id once known (after POST /v1/conversations for `new`).
  final String? conversationId;
  final String? peerUserId;
  final String? peerName;
  final String? peerPhotoUrl;

  /// Oldest first.
  final List<ChatBubble> bubbles;
  final String? olderCursor;
  final bool loadingOlder;
  final Failure? failure;

  /// CH05: the last message was blocked by the contact-details filter.
  final bool filterNotice;

  /// Text to put back in the composer for editing (CH05).
  final String? restoredDraft;

  /// Last send failure that is not a filter or privacy refusal.
  final Failure? sendFailure;

  bool get hasOlder => olderCursor != null;

  ConversationState copyWith({
    ConversationStatus? status,
    String? conversationId,
    String? peerUserId,
    String? peerName,
    String? peerPhotoUrl,
    List<ChatBubble>? bubbles,
    String? Function()? olderCursor,
    bool? loadingOlder,
    Failure? failure,
    bool? filterNotice,
    String? restoredDraft,
    Failure? sendFailure,
  }) => ConversationState(
    status: status ?? this.status,
    conversationId: conversationId ?? this.conversationId,
    peerUserId: peerUserId ?? this.peerUserId,
    peerName: peerName ?? this.peerName,
    peerPhotoUrl: peerPhotoUrl ?? this.peerPhotoUrl,
    bubbles: bubbles ?? this.bubbles,
    olderCursor: olderCursor != null ? olderCursor() : this.olderCursor,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    failure: failure,
    filterNotice: filterNotice ?? this.filterNotice,
    restoredDraft: restoredDraft,
    sendFailure: sendFailure,
  );

  @override
  List<Object?> get props => [
    status,
    conversationId,
    peerUserId,
    peerName,
    peerPhotoUrl,
    bubbles,
    olderCursor,
    loadingOlder,
    failure,
    filterNotice,
    restoredDraft,
    sendFailure,
  ];
}
