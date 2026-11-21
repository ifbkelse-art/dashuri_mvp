import 'package:dashuri_core/dashuri_core.dart';

import '../entities/age_status.dart';
import '../repositories/safety_repository.dart';

/// POST /v1/me/age/declaration
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class SubmitAgeDeclaration
    implements
        UseCase<
          AgeStatus,
          ({String dateOfBirth, IdempotencyKey idempotencyKey})
        > {
  const SubmitAgeDeclaration(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<AgeStatus>> call(
    ({String dateOfBirth, IdempotencyKey idempotencyKey}) input,
  ) => _repository.submitAgeDeclaration(
    dateOfBirth: input.dateOfBirth,
    idempotencyKey: input.idempotencyKey,
  );
}
