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

  /// Finds one ledger entry by id (W09 fallback when no entry was passed).
  /// The API has no single-entry endpoint, so this scans recent pages.
  Future<Result<WalletEntry>> findWalletEntry(String entryId);

  /// Whether the signed-in account is a host (Beans are shown only then).
  Future<Result<bool>> isHost();

  /// Emits whenever the server announces `wallet.updated` on `user:<id>`.
  /// Events are hints: callers re-fetch from the API.
  Stream<void> walletUpdates();
}
