import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_status.dart';
import '../repositories/host_repository.dart';

/// GET /v1/host
// Not final: application tests mock use cases.
class GetHostStatus implements UseCase<HostStatus, NoInput> {
  const GetHostStatus(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostStatus>> call(NoInput input) => _repository.getHostStatus();
}
