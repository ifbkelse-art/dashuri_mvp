import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/host_repository.dart';

/// POST /v1/host/availability/heartbeat
// Not final: application tests mock use cases.
class SendHeartbeat implements UseCase<void, NoInput> {
  const SendHeartbeat(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<void>> call(NoInput input) => _repository.sendHeartbeat();
}
