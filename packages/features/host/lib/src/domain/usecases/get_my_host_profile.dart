import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_profile.dart';
import '../repositories/host_repository.dart';

/// GET /v1/me/profile
// Not final: application tests mock use cases.
class GetMyHostProfile implements UseCase<HostProfile, NoInput> {
  const GetMyHostProfile(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostProfile>> call(NoInput input) =>
      _repository.getMyProfile();
}
