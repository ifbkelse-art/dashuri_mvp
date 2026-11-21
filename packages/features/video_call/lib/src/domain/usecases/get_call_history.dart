import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_session.dart';
import '../repositories/call_repository.dart';

/// GET /v1/calls/history
// Not final: application tests mock use cases.
class GetCallHistory implements UseCase<Page<CallSession>, PageRequest> {
  const GetCallHistory(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<Page<CallSession>>> call(PageRequest input) =>
      _repository.callHistory(input);
}
