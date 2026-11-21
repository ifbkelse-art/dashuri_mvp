import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/safety_repository.dart';

/// DELETE /v1/blocks/{userId}
// Not final: application tests mock use cases.
class UnblockUser implements UseCase<void, String> {
  const UnblockUser(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<void>> call(String input) =>
      _repository.unblockUser(userId: input);
}
