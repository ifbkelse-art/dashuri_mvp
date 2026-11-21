import 'package:dashuri_core/dashuri_core.dart';

import '../entities/wallet_summary.dart';
import '../repositories/wallet_repository.dart';

/// GET /v1/wallet
// Not final: application tests mock use cases.
class GetWalletSummary implements UseCase<WalletSummary, NoInput> {
  const GetWalletSummary(this._repository);

  final WalletRepository _repository;

  @override
  Future<Result<WalletSummary>> call(NoInput input) =>
      _repository.getWalletSummary();
}
