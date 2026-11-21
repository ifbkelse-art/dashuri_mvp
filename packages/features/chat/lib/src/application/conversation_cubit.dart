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
  }) : _list = listMessages,
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
    _hints ??= _watchHints(
      const NoInput(),
    ).where((id) => id == state.conversationId).listen((_) => _refreshNewest());
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
          ),
        );
        unawaited(_markRead(id));
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
    if (isClosed) return;
    if (r case Success(:final value)) {
      _merge(value.items);
      unawaited(_markRead(id));
    }
  }

  void _merge(List<ChatMessage> incoming) {
    final known = {
      for (final b in state.bubbles)
        if (b.serverId != null) b.serverId!,
    };
    final fresh = incoming.where((m) => !known.contains(m.id)).toList();
    if (fresh.isEmpty) return;
    final merged = [
      ...state.bubbles,
      for (final m in fresh) ChatBubble.fromMessage(m, myUserId: _myUserId),
    ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    emit(state.copyWith(bubbles: merged));
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
            ),
          );
        }
      case Err(:final failure) when failure.code == messageRejected:
        _replace(bubble.localId, bubble.withStatus(BubbleStatus.rejected));
        emit(state.copyWith(filterNotice: true, restoredDraft: bubble.body));
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
    await _hints?.cancel();
    return super.close();
  }
}
