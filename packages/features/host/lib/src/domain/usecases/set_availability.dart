import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_status.dart';
import '../repositories/host_repository.dart';

/// PUT /v1/host/availability
// Not final: application tests mock use cases.
class SetAvailability implements UseCase<HostStatus, bool> {
  const SetAvailability(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostStatus>> call(bool input) =>
      _repository.setAvailability(isAvailable: input);
}
