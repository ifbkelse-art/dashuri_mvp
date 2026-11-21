import 'package:dashuri_core/dashuri_core.dart';

import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

/// PATCH /v1/me/profile
// Not final: application tests mock use cases.
class UpdateMyProfile
    implements
        UseCase<
          Profile,
          ({String? displayName, String? bio, List<String>? languages})
        > {
  const UpdateMyProfile(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<Profile>> call(
    ({String? displayName, String? bio, List<String>? languages}) input,
  ) => _repository.updateMyProfile(
    displayName: input.displayName,
    bio: input.bio,
    languages: input.languages,
  );
}
