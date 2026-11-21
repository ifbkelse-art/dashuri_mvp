import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/wallet_repository.dart';

/// GET /v1/me → `is_host`. Beans appear in the wallet only for hosts.
// Not final: application tests mock use cases.
class GetIsHost implements UseCase<bool, NoInput> {
  const GetIsHost(this._repository);

  final WalletRepository _repository;

  @override
  Future<Result<bool>> call(NoInput input) => _repository.isHost();
}
