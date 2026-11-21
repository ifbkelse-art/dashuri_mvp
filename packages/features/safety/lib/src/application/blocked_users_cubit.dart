import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/blocked_user.dart';
import '../domain/usecases/list_blocked_users.dart';
import '../domain/usecases/unblock_user.dart';

part 'blocked_users_state.dart';

/// S06 blocked users: list (cursor pages) and unblock.
class BlockedUsersCubit extends Cubit<BlockedUsersState> {
  BlockedUsersCubit(this._listBlockedUsers, this._unblockUser)
    : super(const BlockedUsersStateInitial());

  final ListBlockedUsers _listBlockedUsers;
  final UnblockUser _unblockUser;

  Future<void> load() async {
    emit(const BlockedUsersStateLoading());
    final result = await _listBlockedUsers(const PageRequest());
    emit(switch (result) {
      Success(:final value) => BlockedUsersStateLoaded(value),
      Err(:final failure) => BlockedUsersStateFailed(failure),
    });
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! BlockedUsersStateLoaded || !s.data.hasMore || s.loadingMore) {
      return;
    }
    emit(BlockedUsersStateLoaded(s.data, loadingMore: true));
    final result = await _listBlockedUsers(
      PageRequest(cursor: s.data.nextCursor),
    );
    emit(switch (result) {
      Success(:final value) => BlockedUsersStateLoaded(
        Page(
          items: [...s.data.items, ...value.items],
          nextCursor: value.nextCursor,
        ),
      ),
      Err(:final failure) => BlockedUsersStateLoaded(
        s.data,
        actionFailure: failure,
      ),
    });
  }

  Future<void> unblock(String userId) async {
    final s = state;
    if (s is! BlockedUsersStateLoaded) return;
    emit(
      BlockedUsersStateLoaded(s.data, unblocking: {...s.unblocking, userId}),
    );
    final result = await _unblockUser(userId);
    final current = state;
    if (current is! BlockedUsersStateLoaded) return;
    final pending = {...current.unblocking}..remove(userId);
    emit(switch (result) {
      // 404: already unblocked; drop it from the list either way.
      Success() || Err(failure: NotFoundFailure()) => BlockedUsersStateLoaded(
        Page(
          items: current.data.items.where((u) => u.userId != userId).toList(),
          nextCursor: current.data.nextCursor,
        ),
        unblocking: pending,
      ),
      Err(:final failure) => BlockedUsersStateLoaded(
        current.data,
        unblocking: pending,
        actionFailure: failure,
      ),
    });
  }
}
