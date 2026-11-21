import 'package:dashuri_core/dashuri_core.dart';

import '../entities/blocked_user.dart';
import '../repositories/safety_repository.dart';

/// GET /v1/blocks
// Not final: application tests mock use cases.
class ListBlockedUsers implements UseCase<Page<BlockedUser>, PageRequest> {
  const ListBlockedUsers(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<Page<BlockedUser>>> call(PageRequest input) =>
      _repository.listBlockedUsers(page: input);
}
