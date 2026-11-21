import 'package:dashuri_core/dashuri_core.dart';

import '../entities/kyc_session.dart';
import '../repositories/host_repository.dart';

/// POST /v1/host/kyc/sessions
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class StartKyc implements UseCase<KycSession, IdempotencyKey> {
  const StartKyc(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<KycSession>> call(IdempotencyKey input) =>
      _repository.startKyc(idempotencyKey: input);
}
