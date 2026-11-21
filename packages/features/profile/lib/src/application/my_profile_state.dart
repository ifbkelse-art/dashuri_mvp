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
  const MyProfileStateLoaded(
    this.data, {
    this.level,
    this.availableDiamonds,
    this.hostModeAvailable = false,
    this.mode = ExperienceMode.customer,
  });

  final Profile data;

  /// Null if the level could not be loaded (the card is hidden).
  final LevelProgress? level;

  /// Null if the wallet could not be loaded (shows "—").
  final int? availableDiamonds;

  /// Approved host: the profile shows a "Switch to host mode" control.
  final bool hostModeAvailable;
  final ExperienceMode mode;

  MyProfileStateLoaded copyWith({ExperienceMode? mode}) => MyProfileStateLoaded(
    data,
    level: level,
    availableDiamonds: availableDiamonds,
    hostModeAvailable: hostModeAvailable,
    mode: mode ?? this.mode,
  );

  @override
  List<Object?> get props => [
    data,
    level,
    availableDiamonds,
    hostModeAvailable,
    mode,
  ];
}

final class MyProfileStateFailed extends MyProfileState {
  const MyProfileStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
