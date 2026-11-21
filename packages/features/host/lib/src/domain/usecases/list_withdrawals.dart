import 'package:dashuri_core/dashuri_core.dart';

import '../entities/withdrawal.dart';
import '../repositories/host_repository.dart';

/// GET /v1/host/withdrawals
// Not final: application tests mock use cases.
class ListWithdrawals implements UseCase<Page<Withdrawal>, PageRequest> {
  const ListWithdrawals(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<Page<Withdrawal>>> call(PageRequest input) =>
      _repository.listWithdrawals(page: input);
}
