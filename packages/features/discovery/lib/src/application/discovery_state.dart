part of 'discovery_cubit.dart';

sealed class DiscoveryState extends Equatable {
  const DiscoveryState(this.filter);

  final DiscoveryFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class DiscoveryStateInitial extends DiscoveryState {
  const DiscoveryStateInitial([super.filter = const DiscoveryFilter()]);
}

/// First page loading (C06 skeleton).
final class DiscoveryStateLoading extends DiscoveryState {
  const DiscoveryStateLoading([super.filter = const DiscoveryFilter()]);
}

/// Hosts so far; [data] accumulates pages, `nextCursor` is the last one's.
final class DiscoveryStateLoaded extends DiscoveryState {
  const DiscoveryStateLoaded(
    this.data, [
    super.filter = const DiscoveryFilter(),
    this.loadingMore = false,
    this.loadMoreFailed = false,
  ]);

  final Page<HostCard> data;
  final bool loadingMore;
  final bool loadMoreFailed;

  @override
  List<Object?> get props => [data, filter, loadingMore, loadMoreFailed];
}

final class DiscoveryStateFailed extends DiscoveryState {
  const DiscoveryStateFailed(
    this.failure, [
    super.filter = const DiscoveryFilter(),
  ]);

  final Failure failure;

  @override
  List<Object?> get props => [failure, filter];
}
