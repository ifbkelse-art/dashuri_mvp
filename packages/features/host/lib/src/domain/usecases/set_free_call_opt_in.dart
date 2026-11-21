import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_status.dart';
import '../repositories/host_repository.dart';

/// PUT /v1/host/free-call-opt-in
// Not final: application tests mock use cases.
class SetFreeCallOptIn implements UseCase<HostStatus, bool> {
  const SetFreeCallOptIn(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostStatus>> call(bool input) =>
      _repository.setFreeCallOptIn(optIn: input);
}
