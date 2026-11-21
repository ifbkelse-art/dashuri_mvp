import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_profile.dart';
import '../repositories/host_repository.dart';

typedef UpdateHostProfileInput = ({
  String displayName,
  String? bio,
  List<String> languages,
});

/// PATCH /v1/me/profile (display name, bio, languages).
// Not final: application tests mock use cases.
class UpdateHostProfile
    implements UseCase<HostProfile, UpdateHostProfileInput> {
  const UpdateHostProfile(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostProfile>> call(UpdateHostProfileInput input) =>
      _repository.updateMyProfile(
        displayName: input.displayName,
        bio: input.bio,
        languages: input.languages,
      );
}
