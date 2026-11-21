import 'package:dashuri_core/dashuri_core.dart';

import '../entities/wallet_entry.dart';
import '../repositories/wallet_repository.dart';

/// GET /v1/wallet/entries
// Not final: application tests mock use cases.
class ListWalletEntries implements UseCase<Page<WalletEntry>, PageRequest> {
  const ListWalletEntries(this._repository);

  final WalletRepository _repository;

  @override
  Future<Result<Page<WalletEntry>>> call(PageRequest input) =>
      _repository.listWalletEntries(page: input);
}
