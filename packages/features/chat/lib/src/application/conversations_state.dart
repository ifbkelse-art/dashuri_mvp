part of 'conversations_cubit.dart';

sealed class ConversationsState extends Equatable {
  const ConversationsState();

  @override
  List<Object?> get props => [];
}

final class ConversationsStateInitial extends ConversationsState {
  const ConversationsStateInitial();
}

final class ConversationsStateLoading extends ConversationsState {
  const ConversationsStateLoading();
}

final class ConversationsStateLoaded extends ConversationsState {
  const ConversationsStateLoaded(
    this.data, {
    this.myUserId,
    this.refreshing = false,
    this.loadingMore = false,
  });

  final Page<Conversation> data;
  final String? myUserId;
  final bool refreshing;
  final bool loadingMore;

  ConversationsStateLoaded copyWith({bool? refreshing, bool? loadingMore}) =>
      ConversationsStateLoaded(
        data,
        myUserId: myUserId,
        refreshing: refreshing ?? this.refreshing,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  @override
  List<Object?> get props => [data, myUserId, refreshing, loadingMore];
}

final class ConversationsStateFailed extends ConversationsState {
  const ConversationsStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
