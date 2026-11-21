import 'package:dashuri_core/dashuri_core.dart';

import '../entities/consent_state.dart';
import '../entities/data_export_request.dart';
import '../entities/deletion_request.dart';
import '../entities/messaging_privacy.dart';

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

  /// GET /v1/me/messaging-privacy
  Future<Result<WhoCanMessage>> getMessagingPrivacy();

  /// PUT /v1/me/messaging-privacy
  Future<Result<WhoCanMessage>> setMessagingPrivacy(WhoCanMessage value);

  /// GET /v1/wallet → available Diamonds (S09 forfeiture warning).
  Future<Result<int>> getAvailableDiamonds();

  /// Grievance (D-22): POST /v1/reports with category `other`.
  Future<Result<String>> submitGrievance({
    required String details,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<void>> signOut();
}
