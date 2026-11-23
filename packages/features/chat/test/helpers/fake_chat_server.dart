import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_chat/feature_chat.dart';

/// EXPERIMENT tests — an in-memory stand-in for the Go chat API with the
/// same rules: one conversation per pair, participant-only access, blocks,
/// Idempotency-Key replay, read markers / `read_by_peer`, and realtime
/// hints (`chat.message`, `chat.read`) to the OTHER participant only.
///
/// Video-call session chat: messages sent with a call id form that call's
/// session; normal Chat leaves them out until [endCall].
///
/// Each user talks to it through [repoFor], so two real cubits (inbox and
/// in-call) on two "devices" exercise the real synchronisation path.
/// Backend semantics are verified separately against Postgres
/// (backend/internal/modules/chat/chat_integration_test.go).
final class FakeChatServer {
  DateTime _clock = DateTime.utc(2026, 11, 22, 10);
  final _convs = <String, ({String a, String b})>{};
  final _messages = <String, List<ChatMessage>>{};
  final _readAt = <String, DateTime>{}; // "$conv|$user"
  final _blocked = <String>{};
  final _replay = <String, ChatMessage>{}; // "$user|$key"
  final _msgCall = <String, String>{}; // message id -> call id (session)
  final _endedCalls = <String>{};
  final _hints =
      StreamController<({String to, String type, String conv})>.broadcast();

  /// Simulates a dead realtime connection: hints are dropped.
  bool realtimeDown = false;

  /// The next send is stored, but the response is lost (network drop after
  /// commit). The client must retry with the same key.
  bool loseNextSendResponse = false;

  int sendRequests = 0;
  final markReadCalls = <String>[];

  DateTime _tick() => _clock = _clock.add(const Duration(seconds: 1));

  ChatRepository repoFor(String userId) => _UserRepo(this, userId);

  String _pairKey(String x, String y) => x.compareTo(y) < 0 ? '$x|$y' : '$y|$x';

  void block(String a, String b) => _blocked.add(_pairKey(a, b));

  /// The call reaches a terminal phase server-side (by /end or the
  /// stale-call job): its session joins normal Chat and both participants
  /// get a `chat.message` hint, like the Go `CallEnded` hook. Idempotent.
  void endCall(String callId) {
    _endedCalls.add(callId);
    for (final e in _messages.entries) {
      if (e.value.any((m) => _msgCall[m.id] == callId)) {
        final c = _convs[e.key]!;
        _emit(c.a, 'chat.message', e.key);
        _emit(c.b, 'chat.message', e.key);
      }
    }
  }

  /// Normal-Chat visibility: not a session message of a live call.
  bool _inChat(ChatMessage m) {
    final call = _msgCall[m.id];
    return call == null || _endedCalls.contains(call);
  }

  /// Every stored message in [conversationId], oldest first.
  List<ChatMessage> stored(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? const []);

  String conversationOf(String a, String b) => _convs.entries
      .firstWhere((e) => _pairKey(e.value.a, e.value.b) == _pairKey(a, b))
      .key;

  String? _peer(String conv, String user) {
    final c = _convs[conv];
    if (c == null) return null;
    if (c.a == user) return c.b;
    if (c.b == user) return c.a;
    return null;
  }

  void _emit(String to, String type, String conv) {
    if (!realtimeDown) _hints.add((to: to, type: type, conv: conv));
  }

  Future<void> dispose() => _hints.close();
}

final class _UserRepo implements ChatRepository {
  _UserRepo(this._s, this._me);

  final FakeChatServer _s;
  final String _me;

  Conversation _conversation(String id) {
    final peer = _s._peer(id, _me)!;
    final msgs = (_s._messages[id] ?? const []).where(_s._inChat).toList();
    return Conversation(
      id: id,
      peerUserId: peer,
      peerDisplayName: peer,
      lastMessagePreview: msgs.isEmpty ? null : msgs.last.body,
      lastMessage: msgs.isEmpty ? null : msgs.last,
      unreadCount: 0,
      updatedAt: msgs.isEmpty ? _s._clock : msgs.last.sentAt,
    );
  }

  @override
  Future<Result<Page<Conversation>>> listConversations({
    required PageRequest page,
  }) async => Success(
    Page(
      items: [
        for (final e in _s._convs.entries)
          if ((e.value.a == _me || e.value.b == _me) &&
              !_s._blocked.contains(_s._pairKey(e.value.a, e.value.b)))
            _conversation(e.key),
      ],
    ),
  );

  @override
  Future<Result<Conversation>> startConversation({
    required String peerUserId,
    required IdempotencyKey idempotencyKey,
  }) async {
    if (_s._blocked.contains(_s._pairKey(_me, peerUserId))) {
      return const Err(BusinessRuleFailure(code: 'blocked'));
    }
    final existing = _s._convs.entries
        .where(
          (e) =>
              _s._pairKey(e.value.a, e.value.b) == _s._pairKey(_me, peerUserId),
        )
        .map((e) => e.key)
        .firstOrNull;
    final id = existing ?? 'conv-${_s._convs.length + 1}';
    _s._convs.putIfAbsent(id, () => (a: _me, b: peerUserId));
    return Success(_conversation(id));
  }

  @override
  Future<Result<Page<ChatMessage>>> listMessages({
    required String conversationId,
    required PageRequest page,
    String? callId,
  }) async {
    final peer = _s._peer(conversationId, _me);
    if (peer == null) return const Err(NotFoundFailure());
    final peerRead = _s._readAt['$conversationId|$peer'];
    final newestFirst = [
      for (final m in (_s._messages[conversationId] ?? const []).reversed)
        if (callId == null ? _s._inChat(m) : _s._msgCall[m.id] == callId)
          ChatMessage(
            id: m.id,
            conversationId: m.conversationId,
            senderId: m.senderId,
            body: m.body,
            sentAt: m.sentAt,
            context: m.context,
            readByPeer:
                m.senderId == _me &&
                peerRead != null &&
                !peerRead.isBefore(m.sentAt),
          ),
    ];
    final start = page.cursor == null ? 0 : int.parse(page.cursor!);
    final end = (start + page.limit).clamp(0, newestFirst.length);
    return Success(
      Page(
        items: newestFirst.sublist(start, end),
        nextCursor: end < newestFirst.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String body,
    required IdempotencyKey idempotencyKey,
    String? callId,
  }) async {
    _s.sendRequests++;
    final peer = _s._peer(conversationId, _me);
    if (peer == null) return const Err(NotFoundFailure());
    final replay = _s._replay['$_me|${idempotencyKey.value}'];
    if (replay != null) return Success(replay); // Idempotency-Key replay
    if (_s._blocked.contains(_s._pairKey(_me, peer))) {
      return const Err(BusinessRuleFailure(code: 'blocked'));
    }
    final m = ChatMessage(
      id: 'm${_s._messages.values.fold(0, (n, l) => n + l.length) + 1}',
      conversationId: conversationId,
      senderId: _me,
      body: body.trim(),
      sentAt: _s._tick(),
      context: callId == null ? MessageContext.chat : MessageContext.call,
    );
    (_s._messages[conversationId] ??= []).add(m);
    if (callId != null) _s._msgCall[m.id] = callId;
    _s._replay['$_me|${idempotencyKey.value}'] = m;
    _s._readAt['$conversationId|$_me'] = m.sentAt;
    _s._emit(peer, 'chat.message', conversationId);
    if (_s.loseNextSendResponse) {
      _s.loseNextSendResponse = false;
      return const Err(NetworkFailure());
    }
    return Success(m);
  }

  @override
  Future<Result<void>> markRead(String conversationId) async {
    final peer = _s._peer(conversationId, _me);
    if (peer == null) return const Err(NotFoundFailure());
    _s.markReadCalls.add(_me);
    final key = '$conversationId|$_me';
    final prev = _s._readAt[key];
    _s._readAt[key] = _s._tick();
    final advanced = (_s._messages[conversationId] ?? const []).any(
      (m) => m.senderId == peer && (prev == null || m.sentAt.isAfter(prev)),
    );
    if (advanced) _s._emit(peer, 'chat.read', conversationId);
    return const Success(null);
  }

  @override
  String? currentUserId() => _me;

  Stream<String> _for(String type) => _s._hints.stream
      .where((h) => h.to == _me && h.type == type)
      .map((h) => h.conv);

  @override
  Stream<String> chatHints() => _for('chat.message');

  @override
  Stream<String> readHints() => _for('chat.read');

  @override
  Future<Result<MessagingPrivacy>> getMessagingPrivacy() async =>
      const Success(MessagingPrivacy(whoCanMessage: 'everyone'));

  @override
  Future<Result<MessagingPrivacy>> updateMessagingPrivacy({
    required String whoCanMessage,
  }) async => Success(MessagingPrivacy(whoCanMessage: whoCanMessage));
}

/// A real [ConversationCubit] for [userId] on [server]: the inbox
/// conversation (no [callId]) or the in-call panel ([callId] set).
ConversationCubit cubitFor(
  FakeChatServer server,
  String userId, {
  required String peerUserId,
  String? conversationId,
  String? callId,
  bool visible = true,
  Duration? pollInterval,
}) {
  final repo = server.repoFor(userId);
  return ConversationCubit(
    listMessages: ListMessages(repo),
    sendMessage: SendMessage(repo),
    startConversation: StartConversation(repo),
    markRead: MarkConversationRead(repo),
    listConversations: ListConversations(repo),
    watchHints: WatchChatHints(repo),
    watchReadHints: WatchReadHints(repo),
    currentUserId: GetCurrentUserId(repo),
    conversationId: conversationId ?? newConversationId,
    peerUserId: peerUserId,
    peerName: peerUserId,
    callId: callId,
    visible: visible,
    pollInterval: pollInterval,
  );
}
