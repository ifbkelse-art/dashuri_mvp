part of 'settings_cubit.dart';

sealed class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

final class SettingsStateInitial extends SettingsState {
  const SettingsStateInitial();
}

final class SettingsStateLoading extends SettingsState {
  const SettingsStateLoading();
}

final class SettingsStateLoaded extends SettingsState {
  const SettingsStateLoaded(this.data);

  final ConsentState data;

  @override
  List<Object?> get props => [data];
}

final class SettingsStateFailed extends SettingsState {
  const SettingsStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
