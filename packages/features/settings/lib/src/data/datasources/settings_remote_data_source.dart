import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/consent_state.dart';
import '../../domain/entities/data_export_request.dart';
import '../../domain/entities/deletion_request.dart';
import '../../domain/entities/messaging_privacy.dart';
import '../models/consent_state_json.dart';
import '../models/data_export_request_json.dart';
import '../models/deletion_request_json.dart';

/// HTTP access to the settings endpoints of the Go API.
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

  Future<Result<WhoCanMessage>> getMessagingPrivacy() => _api.get(
    '/v1/me/messaging-privacy',
    decode: objectDecoder(_whoCanMessage),
  );

  Future<Result<WhoCanMessage>> setMessagingPrivacy(WhoCanMessage value) =>
      _api.put(
        '/v1/me/messaging-privacy',
        decode: objectDecoder(_whoCanMessage),
        body: {'who_can_message': value.wire},
      );

  Future<Result<int>> getAvailableDiamonds() => _api.get(
    '/v1/wallet',
    decode: objectDecoder((json) => json['available_diamonds']! as int),
  );

  /// The grievance is a report of category `other` (D-22). The API requires
  /// a target, so the reporter's own id is used: it marks the report as a
  /// grievance about the service rather than about another user.
  Future<Result<String>> submitGrievance({
    required String userId,
    required String details,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/reports',
    decode: objectDecoder((json) => json['report_id']! as String),
    body: {
      'target_user_id': userId,
      'category': 'other',
      'details': 'Grievance: $details',
    },
    idempotencyKey: idempotencyKey,
  );

  static WhoCanMessage _whoCanMessage(JsonMap json) =>
      WhoCanMessage.fromWire(json['who_can_message']! as String);
}
