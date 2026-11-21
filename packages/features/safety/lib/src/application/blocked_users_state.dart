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
  const BlockedUsersStateLoaded(this.data);

  final Page<BlockedUser> data;

  @override
  List<Object?> get props => [data];
}

final class BlockedUsersStateFailed extends BlockedUsersState {
  const BlockedUsersStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
