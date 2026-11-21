import 'package:dashuri_core/dashuri_core.dart';

import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

/// PATCH /v1/me/profile
// Not final: application tests mock use cases.
class UpdateMyProfile implements UseCase<Profile, ProfileUpdate> {
  const UpdateMyProfile(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<Profile>> call(ProfileUpdate input) =>
      _repository.updateMyProfile(input);
}
