import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_status.dart';
import '../repositories/host_repository.dart';

/// POST /v1/host/application
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class ApplyAsHost implements UseCase<HostStatus, IdempotencyKey> {
  const ApplyAsHost(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostStatus>> call(IdempotencyKey input) =>
      _repository.applyAsHost(idempotencyKey: input);
}
