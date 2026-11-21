import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/discovery_filter.dart';
import '../../domain/entities/host_card.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../datasources/discovery_remote_data_source.dart';

/// Default [DiscoveryRepository]: delegates to the API.
final class DiscoveryRepositoryImpl implements DiscoveryRepository {
  const DiscoveryRepositoryImpl(this._remote);

  final DiscoveryRemoteDataSource _remote;

  @override
  Future<Result<Page<HostCard>>> listAvailableHosts({
    required PageRequest page,
    DiscoveryFilter filter = const DiscoveryFilter(),
  }) => _remote.listAvailableHosts(page: page, filter: filter);

  @override
  Future<Result<HostProfile>> getHost(String userId) => _remote.getHost(userId);

  @override
  Future<Result<int>> onlineCount() => _remote.onlineCount();

  @override
  Future<Result<int>> availableDiamonds() => _remote.availableDiamonds();

  @override
  Future<Result<int?>> approxPaisePerDiamondMilli() =>
      _remote.approxPaisePerDiamondMilli();

  @override
  Future<Result<String>> freeCallCardStatus() => _remote.freeCallCardStatus();

  @override
  Future<Result<String>> myDisplayName() => _remote.myDisplayName();
}
