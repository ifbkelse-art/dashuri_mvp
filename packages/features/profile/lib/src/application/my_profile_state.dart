part of 'my_profile_cubit.dart';

sealed class MyProfileState extends Equatable {
  const MyProfileState();

  @override
  List<Object?> get props => [];
}

final class MyProfileStateInitial extends MyProfileState {
  const MyProfileStateInitial();
}

final class MyProfileStateLoading extends MyProfileState {
  const MyProfileStateLoading();
}

final class MyProfileStateLoaded extends MyProfileState {
  const MyProfileStateLoaded(this.data);

  final Profile data;

  @override
  List<Object?> get props => [data];
}

final class MyProfileStateFailed extends MyProfileState {
  const MyProfileStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
