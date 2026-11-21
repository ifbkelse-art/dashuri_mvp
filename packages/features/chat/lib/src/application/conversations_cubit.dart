import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/conversation.dart';
import '../domain/usecases/chat_extras.dart';
import '../domain/usecases/list_conversations.dart';

part 'conversations_state.dart';

/// CH01/CH03 inbox. Re-fetches on `chat.message` realtime hints.
// Not final: page tests mock cubits.
class ConversationsCubit extends Cubit<ConversationsState> {
  ConversationsCubit(this._listConversations, this._watchHints, this._me)
    : super(const ConversationsStateInitial());

  final ListConversations _listConversations;
  final WatchChatHints _watchHints;
  final GetCurrentUserId _me;
  StreamSubscription<String>? _hints;

  static const pageSize = 30;

  Future<void> load() async {
    emit(const ConversationsStateLoading());
    await _fetchFirst();
    _hints ??= _watchHints(const NoInput()).listen((_) => refresh());
  }

  /// Silent re-fetch of the first page (hint, pull to refresh).
  Future<void> refresh() async {
    final s = state;
    if (s is ConversationsStateLoaded) {
      emit(s.copyWith(refreshing: true));
      await _fetchFirst(previous: s);
    } else if (s is ConversationsStateFailed) {
      await load();
    }
  }

  Future<void> _fetchFirst({ConversationsStateLoaded? previous}) async {
    final result = await _listConversations(const PageRequest(limit: pageSize));
    if (isClosed) return;
    final me = (await _me(
      const NoInput(),
    )).fold<String?>(onSuccess: (v) => v, onFailure: (_) => null);
    emit(switch (result) {
      Success(:final value) => ConversationsStateLoaded(value, myUserId: me),
      Err(:final failure) =>
        previous?.copyWith(refreshing: false) ??
            ConversationsStateFailed(failure),
    });
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! ConversationsStateLoaded || !s.data.hasMore || s.loadingMore) {
      return;
    }
    emit(s.copyWith(loadingMore: true));
    final result = await _listConversations(
      PageRequest(cursor: s.data.nextCursor, limit: pageSize),
    );
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => ConversationsStateLoaded(
        Page(
          items: [
            ...s.data.items,
            ...value.items.where((c) => !s.data.items.any((o) => o.id == c.id)),
          ],
          nextCursor: value.nextCursor,
        ),
        myUserId: s.myUserId,
      ),
      Err() => s.copyWith(loadingMore: false),
    });
  }

  @override
  Future<void> close() async {
    await _hints?.cancel();
    return super.close();
  }
}
