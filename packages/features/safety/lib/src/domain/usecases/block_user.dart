import 'package:dashuri_core/dashuri_core.dart';

import '../entities/blocked_user.dart';
import '../repositories/safety_repository.dart';

/// POST /v1/blocks
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class BlockUser
    implements
        UseCase<BlockedUser, ({String userId, IdempotencyKey idempotencyKey})> {
  const BlockUser(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<BlockedUser>> call(
    ({String userId, IdempotencyKey idempotencyKey}) input,
  ) => _repository.blockUser(
    userId: input.userId,
    idempotencyKey: input.idempotencyKey,
  );
}
