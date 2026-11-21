import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/host_card.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../datasources/discovery_remote_data_source.dart';

/// Default [DiscoveryRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class DiscoveryRepositoryImpl implements DiscoveryRepository {
  const DiscoveryRepositoryImpl(this._remote);

  final DiscoveryRemoteDataSource _remote;

  @override
  Future<Result<Page<HostCard>>> listAvailableHosts({
    required PageRequest page,
  }) => _remote.listAvailableHosts(page: page);
}
