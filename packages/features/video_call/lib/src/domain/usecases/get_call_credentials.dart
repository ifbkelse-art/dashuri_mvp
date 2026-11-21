import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_credentials.dart';
import '../repositories/call_repository.dart';

// Not final: application tests mock use cases.
class GetCallCredentials implements UseCase<CallCredentials, String> {
  const GetCallCredentials(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<CallCredentials>> call(String input) =>
      _repository.getCredentials(input);
}
