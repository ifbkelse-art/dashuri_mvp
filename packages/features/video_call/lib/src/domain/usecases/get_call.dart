import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_session.dart';
import '../repositories/call_repository.dart';

// Not final: application tests mock use cases.
class GetCall implements UseCase<CallSession, String> {
  const GetCall(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<CallSession>> call(String input) => _repository.getCall(input);
}
