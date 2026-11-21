import 'package:dashuri_core/dashuri_core.dart';

import '../entities/free_call_request.dart';
import '../repositories/free_call_repository.dart';

/// POST /v1/free-call/requests
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class RequestFreeCall implements UseCase<FreeCallRequest, IdempotencyKey> {
  const RequestFreeCall(this._repository);

  final FreeCallRepository _repository;

  @override
  Future<Result<FreeCallRequest>> call(IdempotencyKey input) =>
      _repository.requestFreeCall(idempotencyKey: input);
}
