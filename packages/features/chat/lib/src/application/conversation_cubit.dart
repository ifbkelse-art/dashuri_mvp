import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/chat_message.dart';
import '../domain/entities/conversation.dart';
import '../domain/usecases/chat_extras.dart';
import '../domain/usecases/list_conversations.dart';
import '../domain/usecases/list_messages.dart';
import '../domain/usecases/send_message.dart';
import '../domain/usecases/start_conversation.dart';

part 'conversation_state.dart';

/// Route id that means "start a conversation with `peerUserId`".
const newConversationId = 'new';

/// Server rule codes (MVP contract 2.6).
const messagingNotAllowed = 'messaging_not_allowed';
const messageRejected = 'message_rejected';

/// CH02/CH04/CH05: one conversation. Sends with one idempotency key per
/// message (reused on retry), shows an optimistic bubble until the server
/// message replaces it, marks read on open and on new messages.
///
/// The same cubit drives the in-call chat panel ([callId] set): same
/// conversation, same messages, same API. While the panel is closed
/// ([setVisible] false) it keeps receiving, counts unseen messages and does
/// NOT mark them read. [pollInterval] re-fetches as a fallback for missed
/// realtime hints (used during calls).
// Not final: page tests mock cubits.
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit({
    required ListMessages listMessages,
    required SendMessage sendMessage,
    required StartConversation startConversation,
    required MarkConversationRead markRead,
    required ListConversations listConversations,
    required WatchChatHints watchHints,
    required GetCurrentUserId currentUserId,
    required String conversationId,
    String? peerUserId,
    String? peerName,
    Conversation? known,
    DateTime Function()? now,
    WatchReadHints? watchReadHints,
    this.callId,
    Duration? pollInterval,
    bool visible = true,
  }) : _list = listMessages,
       _watchReadHints = watchReadHints,
       _pollInterval = pollInterval,
       _visible = visible,
       _send = sendMessage,
       _start = startConversation,
       _markRead = markRead,
       _listConversations = listConversations,
       _watchHints = watchHints,
       _me = currentUserId,
       _routeId = conversationId,
       _known = known,
       _now = now ?? DateTime.now,
       super(
         ConversationState(
           status: conversationId == newConversationId
               ? ConversationStatus.starting
               : ConversationStatus.loading,
           conversationId: conversationId == newConversationId
               ? null
               : conversationId,
           peerUserId: known?.peerUserId ?? peerUserId,
           peerName: known?.peerDisplayName ?? peerName,
           peerPhotoUrl: known?.peerPhotoUrl,
         ),
       );

  final ListMessages _list;
  final SendMessage _send;
  final StartConversation _start;
  final MarkConversationRead _markRead;
  final ListConversations _listConversations;
  final WatchChatHints _watchHints;
  final GetCurrentUserId _me;
  final String _routeId;
  final Conversation? _known;
  final DateTime Function() _now;
  final WatchReadHints? _watchReadHints;
  final Duration? _pollInterval;

  /// The call this conversation is open in (in-call panel); null in the inbox.
  final String? callId;

  bool _visible;
  StreamSubscription<String>? _readHints;
  Timer? _poll;

  IdempotencyKey? _startKey;

  /// One key per message, by bubble id, reused when the user retries.
  final Map<String, IdempotencyKey> _messageKeys = {};
  String? _myUserId;
  StreamSubscription<String>? _hints;

  static const pageSize = 30;
  static const maxLength = 1000;

  Future<void> start() async {
    _myUserId = (await _me(
      const NoInput(),
    )).fold(onSuccess: (v) => v, onFailure: (_) => null);
    if (_routeId == newConversationId) {
      final peer = state.peerUserId;
      if (peer == null) {
        emit(
          state.copyWith(
            status: ConversationStatus.failed,
            failure: const NotFoundFailure(),
          ),
        );
        return;
      }
      emit(state.copyWith(status: ConversationStatus.starting));
      final key = _startKey ??= IdempotencyKey.generate();
      final r = await _start((peerUserId: peer, idempotencyKey: key));
      if (isClosed) return;
      switch (r) {
        case Err(:final failure):
          emit(
            state.copyWith(
              status: failure.code == messagingNotAllowed
                  ? ConversationStatus.restricted
                  : ConversationStatus.failed,
              failure: failure,
            ),
          );
          return;
        case Success(:final value):
          emit(
            state.copyWith(
              conversationId: value.id,
              peerName: value.peerDisplayName.isEmpty
                  ? null
                  : value.peerDisplayName,
              peerPhotoUrl: value.peerPhotoUrl,
            ),
          );
      }
    } else if (_known == null) {
      await _findPeer();
    }
    await _loadNewest();
    if (isClosed) return;
    _hints ??= _watchHints(
      const NoInput(),
    ).where((id) => id == state.conversationId).listen((_) => _refreshNewest());
    _readHints ??= _watchReadHints
        ?.call(const NoInput())
        .where((id) => id == state.conversationId)
        .listen((_) => _refreshNewest());
    final every = _pollInterval;
    if (every != null) {
      _poll ??= Timer.periodic(every, (_) => _refreshNewest());
    }
  }

  /// The view showing this conversation was opened (true) or hidden.
  /// Becoming visible clears the unseen count and marks the conversation read.
  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    if (!visible || isClosed) return;
    if (state.unseenCount != 0 || state.latestUnseen != null) {
      emit(state.copyWith(unseenCount: 0, latestUnseen: () => null));
    }
    final id = state.conversationId;
    if (id != null && state.status == ConversationStatus.ready) {
      unawaited(_markRead(id));
    }
  }

  /// Hides the incoming-message preview without opening the conversation.
  void dismissPreview() {
    if (state.latestUnseen != null) {
      emit(state.copyWith(latestUnseen: () => null));
    }
  }

  DateTime? _readUpTo(List<ChatMessage> items) {
    DateTime? at = state.peerReadUpTo;
    for (final m in items) {
      if (m.readByPeer && m.senderId == _myUserId) {
        if (at == null || m.sentAt.isAfter(at)) at = m.sentAt;
      }
    }
    return at;
  }

  Future<void> retry() => start();

  /// The inbox entry gives peer details; deep links look it up.
  Future<void> _findPeer() async {
    final r = await _listConversations(const PageRequest(limit: 100));
    if (r case Success(:final value)) {
      for (final c in value.items) {
        if (c.id == _routeId) {
          emit(
            state.copyWith(
              peerUserId: c.peerUserId,
              peerName: c.peerDisplayName,
              peerPhotoUrl: c.peerPhotoUrl,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadNewest() async {
    final id = state.conversationId!;
    emit(state.copyWith(status: ConversationStatus.loading));
    final r = await _list((
      conversationId: id,
      page: const PageRequest(limit: pageSize),
    ));
    if (isClosed) return;
    switch (r) {
      case Err(:final failure):
        emit(
          state.copyWith(status: ConversationStatus.failed, failure: failure),
        );
      case Success(:final value):
        emit(
          state.copyWith(
            status: ConversationStatus.ready,
            bubbles: _toBubbles(value.items),
            olderCursor: () => value.nextCursor,
            peerReadUpTo: _readUpTo(value.items),
          ),
        );
        if (_visible) unawaited(_markRead(id));
    }
  }

  List<ChatBubble> _toBubbles(List<ChatMessage> newestFirst) => [
    for (final m in newestFirst.reversed)
      ChatBubble.fromMessage(m, myUserId: _myUserId),
  ];

  /// A hint arrived: fetch the newest page and merge unseen messages.
  Future<void> _refreshNewest() async {
    final id = state.conversationId;
    if (id == null || state.status != ConversationStatus.ready) return;
    final r = await _list((
      conversationId: id,
      page: const PageRequest(limit: pageSize),
    ));
    if (isClosed || state.status != ConversationStatus.ready) return;
    if (r case Success(:final value)) {
      final freshFromPeer = _merge(value.items);
      if (freshFromPeer > 0 && _visible) unawaited(_markRead(id));
    }
  }

  /// Adds messages not shown yet (deduplicated by server id) and updates
  /// read receipts. Returns how many new messages came from the peer.
  int _merge(List<ChatMessage> incoming) {
    final known = {
      for (final b in state.bubbles)
        if (b.serverId != null) b.serverId!,
    };
    final fresh = [
      for (final m in incoming)
        if (!known.contains(m.id))
          ChatBubble.fromMessage(m, myUserId: _myUserId),
    ];
    final readUpTo = _readUpTo(incoming);
    if (fresh.isEmpty) {
      if (readUpTo != state.peerReadUpTo) {
        emit(state.copyWith(peerReadUpTo: readUpTo));
      }
      return 0;
    }
    final merged = [...state.bubbles, ...fresh]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final fromPeer = fresh.where((b) => !b.mine).toList();
    emit(
      state.copyWith(
        bubbles: merged,
        peerReadUpTo: readUpTo,
        unseenCount: _visible ? 0 : state.unseenCount + fromPeer.length,
        latestUnseen: _visible || fromPeer.isEmpty ? null : () => fromPeer.last,
      ),
    );
    return fromPeer.length;
  }

  Future<void> loadOlder() async {
    final id = state.conversationId;
    if (id == null ||
        !state.hasOlder ||
        state.loadingOlder ||
        state.status != ConversationStatus.ready) {
      return;
    }
    emit(state.copyWith(loadingOlder: true));
    final r = await _list((
      conversationId: id,
      page: PageRequest(cursor: state.olderCursor, limit: pageSize),
    ));
    if (isClosed) return;
    switch (r) {
      case Err():
        emit(state.copyWith(loadingOlder: false));
      case Success(:final value):
        final known = state.bubbles.map((b) => b.serverId).toSet();
        emit(
          state.copyWith(
            loadingOlder: false,
            bubbles: [
              ..._toBubbles(
                value.items.where((m) => !known.contains(m.id)).toList(),
              ),
              ...state.bubbles,
            ],
            olderCursor: () => value.nextCursor,
          ),
        );
    }
  }

  /// Sends [text] with a new idempotency key (one per message).
  Future<void> send(String text) async {
    final body = text.trim();
    final id = state.conversationId;
    if (body.isEmpty ||
        body.length > maxLength ||
        id == null ||
        state.status != ConversationStatus.ready) {
      return;
    }
    final key = IdempotencyKey.generate();
    _messageKeys[key.value] = key;
    final bubble = ChatBubble(
      localId: key.value,
      body: body,
      sentAt: _now(),
      mine: true,
      status: BubbleStatus.sending,
      context: callId == null ? MessageContext.chat : MessageContext.call,
    );
    emit(
      state.copyWith(bubbles: [...state.bubbles, bubble], filterNotice: false),
    );
    await _deliver(id, bubble, key);
  }

  /// Retries a failed bubble with the SAME key.
  Future<void> retrySend(String localId) async {
    final id = state.conversationId;
    final bubble = state.bubbles
        .where((b) => b.localId == localId && b.status == BubbleStatus.failed)
        .firstOrNull;
    if (id == null || bubble == null) return;
    final sending = bubble.withStatus(BubbleStatus.sending);
    _replace(localId, sending);
    await _deliver(id, sending, _messageKeys[localId]!);
  }

  Future<void> _deliver(
    String conversationId,
    ChatBubble bubble,
    IdempotencyKey key,
  ) async {
    final r = await _send((
      conversationId: conversationId,
      body: bubble.body,
      idempotencyKey: key,
      callId: callId,
    ));
    if (isClosed) return;
    switch (r) {
      case Success(:final value):
        final already = state.bubbles.any((b) => b.serverId == value.id);
        if (already) {
          emit(
            state.copyWith(
              bubbles: state.bubbles
                  .where((b) => b.localId != bubble.localId)
                  .toList(),
            ),
          );
        } else {
          _replace(
            bubble.localId,
            ChatBubble(
              localId: bubble.localId,
              serverId: value.id,
              body: value.body,
              sentAt: value.sentAt,
              mine: true,
              context: value.context,
            ),
          );
        }
      case Err(:final failure) when failure.code == messageRejected:
        _replace(bubble.localId, bubble.withStatus(BubbleStatus.rejected));
        emit(state.copyWith(filterNotice: true, restoredDraft: bubble.body));
      // A block (either way) or a restricted account: retrying cannot help.
      case Err(:final failure)
          when failure.code == 'blocked' ||
              failure.code == 'account_restricted':
        _replace(bubble.localId, bubble.withStatus(BubbleStatus.rejected));
        emit(state.copyWith(sendFailure: failure));
      case Err(:final failure) when failure.code == messagingNotAllowed:
        emit(
          state.copyWith(
            status: ConversationStatus.restricted,
            bubbles: state.bubbles
                .where((b) => b.localId != bubble.localId)
                .toList(),
            failure: failure,
          ),
        );
      case Err(:final failure):
        _replace(bubble.localId, bubble.withStatus(BubbleStatus.failed));
        emit(state.copyWith(sendFailure: failure));
    }
  }

  void _replace(String localId, ChatBubble next) => emit(
    state.copyWith(
      bubbles: [for (final b in state.bubbles) b.localId == localId ? next : b],
      filterNotice: state.filterNotice,
    ),
  );

  /// Hides the CH05 notice once the user edits the message.
  void dismissFilterNotice() {
    if (state.filterNotice) emit(state.copyWith(filterNotice: false));
  }

  @override
  Future<void> close() async {
    _poll?.cancel();
    await _readHints?.cancel();
    await _hints?.cancel();
    return super.close();
  }
}
