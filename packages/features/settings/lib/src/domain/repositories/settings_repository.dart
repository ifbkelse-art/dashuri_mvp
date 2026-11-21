import 'package:dashuri_core/dashuri_core.dart';

import '../entities/consent_state.dart';
import '../entities/data_export_request.dart';
import '../entities/deletion_request.dart';

/// Contract for settings data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class SettingsRepository {
  Future<Result<ConsentState>> getConsents();

  Future<Result<ConsentState>> updateConsents({
    required bool analytics,
    required bool marketing,
  });

  Future<Result<DeletionRequest>> requestAccountDeletion({
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<DataExportRequest>> requestDataExport({
    required IdempotencyKey idempotencyKey,
  });
}
