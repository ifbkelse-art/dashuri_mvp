import 'package:dashuri_core/dashuri_core.dart';

import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

/// GET /v1/me/profile
// Not final: application tests mock use cases.
class GetMyProfile implements UseCase<Profile, NoInput> {
  const GetMyProfile(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<Profile>> call(NoInput input) => _repository.getMyProfile();
}
