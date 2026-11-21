import 'package:dashuri_core/dashuri_core.dart';

import '../entities/wallet_entry.dart';
import '../repositories/wallet_repository.dart';

/// Looks up one ledger entry (W09 deep link without an entry in hand).
// Not final: application tests mock use cases.
class FindWalletEntry implements UseCase<WalletEntry, String> {
  const FindWalletEntry(this._repository);

  final WalletRepository _repository;

  @override
  Future<Result<WalletEntry>> call(String entryId) =>
      _repository.findWalletEntry(entryId);
}
