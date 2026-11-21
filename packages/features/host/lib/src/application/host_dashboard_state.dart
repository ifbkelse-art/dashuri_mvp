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
  const HostDashboardStateLoaded(this.data);

  final HostStatus data;

  @override
  List<Object?> get props => [data];
}

final class HostDashboardStateFailed extends HostDashboardState {
  const HostDashboardStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
