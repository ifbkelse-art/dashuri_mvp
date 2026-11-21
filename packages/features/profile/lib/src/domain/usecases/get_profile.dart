import 'package:dashuri_core/dashuri_core.dart';

import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

/// GET /v1/profiles/{userId}
// Not final: application tests mock use cases.
class GetProfile implements UseCase<Profile, String> {
  const GetProfile(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<Profile>> call(String input) =>
      _repository.getProfile(userId: input);
}
