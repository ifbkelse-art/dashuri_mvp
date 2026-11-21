import 'package:dashuri_core/dashuri_core.dart';

import '../entities/deletion_request.dart';
import '../repositories/settings_repository.dart';

/// POST /v1/me/deletion-requests
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class RequestAccountDeletion
    implements UseCase<DeletionRequest, IdempotencyKey> {
  const RequestAccountDeletion(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<DeletionRequest>> call(IdempotencyKey input) =>
      _repository.requestAccountDeletion(idempotencyKey: input);
}
