import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_session.dart';
import '../repositories/call_repository.dart';

// Not final: application tests mock use cases.
class AcceptCall implements UseCase<CallSession, String> {
  const AcceptCall(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<CallSession>> call(String input) =>
      _repository.acceptCall(input);
}
