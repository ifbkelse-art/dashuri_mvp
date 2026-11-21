part of 'blocked_users_cubit.dart';

sealed class BlockedUsersState extends Equatable {
  const BlockedUsersState();

  @override
  List<Object?> get props => [];
}

final class BlockedUsersStateInitial extends BlockedUsersState {
  const BlockedUsersStateInitial();
}

final class BlockedUsersStateLoading extends BlockedUsersState {
  const BlockedUsersStateLoading();
}

final class BlockedUsersStateLoaded extends BlockedUsersState {
  const BlockedUsersStateLoaded(
    this.data, {
    this.loadingMore = false,
    this.unblocking = const {},
    this.actionFailure,
  });

  final Page<BlockedUser> data;
  final bool loadingMore;

  /// User ids with an unblock in flight.
  final Set<String> unblocking;

  /// Last failed unblock or load-more, shown as a snackbar.
  final Failure? actionFailure;

  @override
  List<Object?> get props => [data, loadingMore, unblocking, actionFailure];
}

final class BlockedUsersStateFailed extends BlockedUsersState {
  const BlockedUsersStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
