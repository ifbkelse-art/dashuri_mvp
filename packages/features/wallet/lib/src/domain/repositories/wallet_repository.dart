import 'package:dashuri_core/dashuri_core.dart';

import '../entities/wallet_entry.dart';
import '../entities/wallet_summary.dart';

/// Contract for wallet data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class WalletRepository {
  Future<Result<WalletSummary>> getWalletSummary();

  Future<Result<Page<WalletEntry>>> listWalletEntries({
    required PageRequest page,
  });
}
