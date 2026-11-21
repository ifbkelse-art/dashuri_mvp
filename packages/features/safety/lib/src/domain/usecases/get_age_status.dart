import 'package:dashuri_core/dashuri_core.dart';

import '../entities/age_status.dart';
import '../repositories/safety_repository.dart';

/// GET /v1/me/age
// Not final: application tests mock use cases.
class GetAgeStatus implements UseCase<AgeStatus, NoInput> {
  const GetAgeStatus(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<AgeStatus>> call(NoInput input) => _repository.getAgeStatus();
}
