import 'package:dashuri_core/dashuri_core.dart';

import '../entities/appeal_receipt.dart';
import '../repositories/safety_repository.dart';

/// POST /v1/appeals
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class SubmitAppeal
    implements
        UseCase<
          AppealReceipt,
          ({
            String enforcementId,
            String statement,
            IdempotencyKey idempotencyKey,
          })
        > {
  const SubmitAppeal(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<AppealReceipt>> call(
    ({String enforcementId, String statement, IdempotencyKey idempotencyKey})
    input,
  ) => _repository.submitAppeal(
    enforcementId: input.enforcementId,
    statement: input.statement,
    idempotencyKey: input.idempotencyKey,
  );
}
