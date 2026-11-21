import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/consent_state.dart';
import '../../domain/entities/data_export_request.dart';
import '../../domain/entities/deletion_request.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_data_source.dart';

/// Default [SettingsRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._remote);

  final SettingsRemoteDataSource _remote;

  @override
  Future<Result<ConsentState>> getConsents() => _remote.getConsents();

  @override
  Future<Result<ConsentState>> updateConsents({
    required bool analytics,
    required bool marketing,
  }) => _remote.updateConsents(analytics: analytics, marketing: marketing);

  @override
  Future<Result<DeletionRequest>> requestAccountDeletion({
    required IdempotencyKey idempotencyKey,
  }) => _remote.requestAccountDeletion(idempotencyKey: idempotencyKey);

  @override
  Future<Result<DataExportRequest>> requestDataExport({
    required IdempotencyKey idempotencyKey,
  }) => _remote.requestDataExport(idempotencyKey: idempotencyKey);
}
