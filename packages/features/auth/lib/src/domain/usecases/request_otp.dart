import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/auth_repository.dart';

// Not final: application tests mock use cases.
class RequestOtp implements UseCase<void, String> {
  const RequestOtp(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String input) => _repository.requestOtp(input);
}
