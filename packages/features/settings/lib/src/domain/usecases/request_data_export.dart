import 'package:dashuri_core/dashuri_core.dart';

import '../entities/data_export_request.dart';
import '../repositories/settings_repository.dart';

/// POST /v1/me/data-exports
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class RequestDataExport implements UseCase<DataExportRequest, IdempotencyKey> {
  const RequestDataExport(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<DataExportRequest>> call(IdempotencyKey input) =>
      _repository.requestDataExport(idempotencyKey: input);
}
