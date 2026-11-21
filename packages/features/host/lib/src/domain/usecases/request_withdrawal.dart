import 'package:dashuri_core/dashuri_core.dart';

import '../entities/withdrawal.dart';
import '../repositories/host_repository.dart';

/// POST /v1/host/withdrawals
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class RequestWithdrawal
    implements
        UseCase<Withdrawal, ({int beans, IdempotencyKey idempotencyKey})> {
  const RequestWithdrawal(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<Withdrawal>> call(
    ({int beans, IdempotencyKey idempotencyKey}) input,
  ) => _repository.requestWithdrawal(
    beans: input.beans,
    idempotencyKey: input.idempotencyKey,
  );
}
