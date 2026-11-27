import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/discovery_repository.dart';

/// Emits whenever the server says this user's balances changed, so the
/// header's Diamond pill can be re-read instead of going stale.
// Not final: application tests mock use cases.
class WatchBalanceChanges {
  const WatchBalanceChanges(this._repository);

  final DiscoveryRepository _repository;

  Stream<void> call(NoInput _) => _repository.walletUpdates();
}
