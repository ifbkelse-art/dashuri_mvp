import 'package:dashuri_core/dashuri_core.dart';

import '../entities/level_progress.dart';
import '../repositories/profile_repository.dart';

/// GET /v1/me/level
// Not final: application tests mock use cases.
class GetMyLevel implements UseCase<LevelProgress, NoInput> {
  const GetMyLevel(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<LevelProgress>> call(NoInput input) => _repository.getMyLevel();
}
