part of 'host_dashboard_cubit.dart';

sealed class HostDashboardState extends Equatable {
  const HostDashboardState();

  @override
  List<Object?> get props => [];
}

final class HostDashboardStateInitial extends HostDashboardState {
  const HostDashboardStateInitial();
}

final class HostDashboardStateLoading extends HostDashboardState {
  const HostDashboardStateLoading();
}

final class HostDashboardStateLoaded extends HostDashboardState {
  const HostDashboardStateLoaded(
    this.data, {
    this.profile,
    this.updating = false,
    this.actionFailure,
  });

  final HostStatus data;

  /// Own profile for the greeting; null when it could not be loaded.
  final HostProfile? profile;

  /// An availability or opt-in change is in flight.
  final bool updating;

  /// The last availability/opt-in change failed (shown as a snackbar).
  final Failure? actionFailure;

  HostDashboardStateLoaded copyWith({
    HostStatus? data,
    bool? updating,
    Failure? actionFailure,
  }) => HostDashboardStateLoaded(
    data ?? this.data,
    profile: profile,
    updating: updating ?? this.updating,
    actionFailure: actionFailure,
  );

  @override
  List<Object?> get props => [data, profile, updating, actionFailure];
}

final class HostDashboardStateFailed extends HostDashboardState {
  const HostDashboardStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
