part of 'inbox_cubit.dart';

sealed class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

final class InboxStateInitial extends InboxState {
  const InboxStateInitial();
}

final class InboxStateLoading extends InboxState {
  const InboxStateLoading();
}

final class InboxStateLoaded extends InboxState {
  const InboxStateLoaded(this.data, {this.loadingMore = false});

  final Page<InboxItem> data;
  final bool loadingMore;

  int get unreadCount => data.items.where((i) => i.readAt == null).length;

  @override
  List<Object?> get props => [data, loadingMore];
}

final class InboxStateFailed extends InboxState {
  const InboxStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
