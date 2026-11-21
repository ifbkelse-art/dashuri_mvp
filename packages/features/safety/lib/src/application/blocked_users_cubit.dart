import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/blocked_user.dart';
import '../domain/usecases/list_blocked_users.dart';

part 'blocked_users_state.dart';

/// Loads `Page<BlockedUser>` for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class BlockedUsersCubit extends Cubit<BlockedUsersState> {
  BlockedUsersCubit(this._listBlockedUsers)
    : super(const BlockedUsersStateInitial());

  final ListBlockedUsers _listBlockedUsers;

  Future<void> load() async {
    emit(const BlockedUsersStateLoading());
    final result = await _listBlockedUsers(const PageRequest());
    emit(switch (result) {
      Success(:final value) => BlockedUsersStateLoaded(value),
      Err(:final failure) => BlockedUsersStateFailed(failure),
    });
  }
}
