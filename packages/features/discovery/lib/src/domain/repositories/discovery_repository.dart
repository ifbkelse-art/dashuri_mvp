import 'package:dashuri_core/dashuri_core.dart';

import '../entities/discovery_filter.dart';
import '../entities/host_card.dart';

/// Contract for discovery data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class DiscoveryRepository {
  Future<Result<Page<HostCard>>> listAvailableHosts({
    required PageRequest page,
    DiscoveryFilter filter = const DiscoveryFilter(),
  });

  /// GET /v1/discovery/hosts/{id} (404 when blocked either way).
  Future<Result<HostProfile>> getHost(String userId);

  /// GET /v1/discovery/summary → online_count.
  Future<Result<int>> onlineCount();

  /// GET /v1/wallet → available_diamonds.
  Future<Result<int>> availableDiamonds();

  /// GET /v1/purchases/packages → approx_paise_per_diamond_milli (D-07).
  Future<Result<int?>> approxPaisePerDiamondMilli();

  /// GET /v1/free-call/card → status (`available`, `used`, …).
  Future<Result<String>> freeCallCardStatus();

  /// GET /v1/me/profile → display_name (greeting).
  Future<Result<String>> myDisplayName();

  /// `wallet.updated` hints on `user:<id>` (purchase, call settlement,
  /// gift, refund, adjustment). A hint only: re-read the balance from the API.
  Stream<void> walletUpdates();
}
