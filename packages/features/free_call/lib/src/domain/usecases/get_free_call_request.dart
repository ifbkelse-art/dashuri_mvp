import 'package:dashuri_core/dashuri_core.dart';

import '../entities/free_call_request.dart';
import '../repositories/free_call_repository.dart';

/// GET /v1/free-call/requests/{requestId}
// Not final: application tests mock use cases.
class GetFreeCallRequest implements UseCase<FreeCallRequest, String> {
  const GetFreeCallRequest(this._repository);

  final FreeCallRepository _repository;

  @override
  Future<Result<FreeCallRequest>> call(String input) =>
      _repository.getFreeCallRequest(requestId: input);
}
