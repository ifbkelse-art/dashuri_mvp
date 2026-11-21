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
  const ConversationsStateLoaded(this.data);

  final Page<Conversation> data;

  @override
  List<Object?> get props => [data];
}

final class ConversationsStateFailed extends ConversationsState {
  const ConversationsStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
