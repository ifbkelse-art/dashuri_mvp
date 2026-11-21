import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/inbox_item.dart';
import '../domain/usecases/list_inbox.dart';
import '../domain/usecases/mark_read.dart';
import '../domain/usecases/watch_new_notifications.dart';

part 'inbox_state.dart';

/// C11 notifications inbox: first page, more pages, mark read, and a
/// silent refresh on each realtime `notification.created` hint.
class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._listInbox, this._markRead, this._watch, this._clock)
    : super(const InboxStateInitial());

  final ListInbox _listInbox;
  final MarkRead _markRead;
  final WatchNewNotifications _watch;
  final Clock _clock;
  StreamSubscription<void>? _subscription;

  Future<void> load() async {
    _subscription ??= _watch(const NoInput()).listen((_) => refresh());
    emit(const InboxStateLoading());
    final result = await _listInbox(const PageRequest());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => InboxStateLoaded(value),
      Err(:final failure) => InboxStateFailed(failure),
    });
  }

  /// Re-fetches the first page without showing a spinner.
  Future<void> refresh() async {
    final result = await _listInbox(const PageRequest());
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(InboxStateLoaded(value));
      case Err(:final failure):
        if (state is! InboxStateLoaded) emit(InboxStateFailed(failure));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! InboxStateLoaded || !s.data.hasMore || s.loadingMore) return;
    emit(InboxStateLoaded(s.data, loadingMore: true));
    final result = await _listInbox(PageRequest(cursor: s.data.nextCursor));
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => InboxStateLoaded(
        Page(
          items: [...s.data.items, ...value.items],
          nextCursor: value.nextCursor,
        ),
      ),
      Err() => InboxStateLoaded(s.data),
    });
  }

  /// Optimistic: shows the item as read at once; reverts if the call fails.
  Future<void> markRead(String id) async {
    final s = state;
    if (s is! InboxStateLoaded) return;
    final item = s.data.items.where((i) => i.id == id).firstOrNull;
    if (item == null || item.readAt != null) return;
    _replace(id, _clock.now());
    final result = await _markRead(id);
    if (result is Err<void>) _replace(id, null);
  }

  Future<void> markAllRead() async {
    final s = state;
    if (s is! InboxStateLoaded) return;
    final unread = s.data.items.where((i) => i.readAt == null).toList();
    await Future.wait(unread.map((i) => markRead(i.id)));
  }

  void _replace(String id, DateTime? readAt) {
    final s = state;
    if (s is! InboxStateLoaded || isClosed) return;
    emit(
      InboxStateLoaded(
        Page(
          items: [
            for (final i in s.data.items)
              i.id == id
                  ? InboxItem(
                      id: i.id,
                      kind: i.kind,
                      title: i.title,
                      body: i.body,
                      createdAt: i.createdAt,
                      readAt: readAt,
                    )
                  : i,
          ],
          nextCursor: s.data.nextCursor,
        ),
        loadingMore: s.loadingMore,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
