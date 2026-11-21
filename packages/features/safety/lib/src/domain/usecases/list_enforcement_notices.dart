import 'package:dashuri_core/dashuri_core.dart';

import '../entities/enforcement_notice.dart';
import '../repositories/safety_repository.dart';

/// GET /v1/me/enforcement
// Not final: application tests mock use cases.
class ListEnforcementNotices
    implements UseCase<Page<EnforcementNotice>, PageRequest> {
  const ListEnforcementNotices(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<Page<EnforcementNotice>>> call(PageRequest input) =>
      _repository.listEnforcementNotices(page: input);
}
