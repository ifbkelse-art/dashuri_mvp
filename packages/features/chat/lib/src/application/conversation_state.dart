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

/// What the sender sees under their own message (delivery state).
enum DeliveryState { sending, sent, read, failed, notSent }

/// One row of the message list: a server message or a local optimistic one.
final class ChatBubble extends Equatable {
  const ChatBubble({
    required this.localId,
    required this.body,
    required this.sentAt,
    required this.mine,
    this.status = BubbleStatus.sent,
    this.serverId,
    this.context = MessageContext.chat,
  });

  factory ChatBubble.fromMessage(ChatMessage m, {required String? myUserId}) =>
      ChatBubble(
        localId: m.id,
        serverId: m.id,
        body: m.body,
        sentAt: m.sentAt,
        mine: m.senderId == myUserId,
        context: m.context,
      );

  /// Server id for sent messages; the idempotency key for local ones.
  final String localId;
  final String? serverId;
  final String body;
  final DateTime sentAt;
  final bool mine;
  final BubbleStatus status;

  /// Sent from the inbox or during a video call (metadata only).
  final MessageContext context;

  ChatBubble withStatus(BubbleStatus s) => ChatBubble(
    localId: localId,
    serverId: serverId,
    body: body,
    sentAt: sentAt,
    mine: mine,
    status: s,
    context: context,
  );

  @override
  List<Object?> get props => [
    localId,
    serverId,
    body,
    sentAt,
    mine,
    status,
    context,
  ];
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
    this.peerReadUpTo,
    this.unseenCount = 0,
    this.latestUnseen,
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

  /// The peer has read my messages sent at or before this time.
  final DateTime? peerReadUpTo;

  /// Messages from the peer that arrived while the view was hidden (the
  /// in-call panel closed). Reset when it becomes visible.
  final int unseenCount;

  /// The newest of those, for a short preview on the call screen.
  final ChatBubble? latestUnseen;

  bool get hasOlder => olderCursor != null;

  /// Delivery state of one of my bubbles (null for received messages).
  DeliveryState? deliveryOf(ChatBubble b) {
    if (!b.mine) return null;
    return switch (b.status) {
      BubbleStatus.sending => DeliveryState.sending,
      BubbleStatus.failed => DeliveryState.failed,
      BubbleStatus.rejected => DeliveryState.notSent,
      BubbleStatus.sent =>
        peerReadUpTo != null && !b.sentAt.isAfter(peerReadUpTo!)
            ? DeliveryState.read
            : DeliveryState.sent,
    };
  }

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
    DateTime? peerReadUpTo,
    int? unseenCount,
    ChatBubble? Function()? latestUnseen,
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
    peerReadUpTo: peerReadUpTo ?? this.peerReadUpTo,
    unseenCount: unseenCount ?? this.unseenCount,
    latestUnseen: latestUnseen != null ? latestUnseen() : this.latestUnseen,
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
    peerReadUpTo,
    unseenCount,
    latestUnseen,
  ];
}
