import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/consent_state.dart';
import '../../domain/entities/data_export_request.dart';
import '../../domain/entities/deletion_request.dart';
import '../models/consent_state_json.dart';
import '../models/data_export_request_json.dart';
import '../models/deletion_request_json.dart';

/// HTTP access to the settings endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class SettingsRemoteDataSource {
  const SettingsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<ConsentState>> getConsents() =>
      _api.get('/v1/me/consents', decode: objectDecoder(consentStateFromJson));

  Future<Result<ConsentState>> updateConsents({
    required bool analytics,
    required bool marketing,
  }) => _api.put(
    '/v1/me/consents',
    decode: objectDecoder(consentStateFromJson),
    body: {'analytics': analytics, 'marketing': marketing},
  );

  Future<Result<DeletionRequest>> requestAccountDeletion({
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/me/deletion-requests',
    decode: objectDecoder(deletionRequestFromJson),
    idempotencyKey: idempotencyKey,
  );

  Future<Result<DataExportRequest>> requestDataExport({
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/me/data-exports',
    decode: objectDecoder(dataExportRequestFromJson),
    idempotencyKey: idempotencyKey,
  );
}
