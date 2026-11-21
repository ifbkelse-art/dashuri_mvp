part of 'free_call_card_cubit.dart';

sealed class FreeCallCardState extends Equatable {
  const FreeCallCardState();

  @override
  List<Object?> get props => [];
}

final class FreeCallCardStateInitial extends FreeCallCardState {
  const FreeCallCardStateInitial();
}

final class FreeCallCardStateLoading extends FreeCallCardState {
  const FreeCallCardStateLoading();
}

final class FreeCallCardStateLoaded extends FreeCallCardState {
  const FreeCallCardStateLoaded(this.data);

  final FreeCallCard data;

  @override
  List<Object?> get props => [data];
}

final class FreeCallCardStateFailed extends FreeCallCardState {
  const FreeCallCardStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
