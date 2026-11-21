part of 'discovery_cubit.dart';

sealed class DiscoveryState extends Equatable {
  const DiscoveryState();

  @override
  List<Object?> get props => [];
}

final class DiscoveryStateInitial extends DiscoveryState {
  const DiscoveryStateInitial();
}

final class DiscoveryStateLoading extends DiscoveryState {
  const DiscoveryStateLoading();
}

final class DiscoveryStateLoaded extends DiscoveryState {
  const DiscoveryStateLoaded(this.data);

  final Page<HostCard> data;

  @override
  List<Object?> get props => [data];
}

final class DiscoveryStateFailed extends DiscoveryState {
  const DiscoveryStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
