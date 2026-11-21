import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_card.dart';

/// Contract for discovery data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class DiscoveryRepository {
  Future<Result<Page<HostCard>>> listAvailableHosts({
    required PageRequest page,
  });
}
