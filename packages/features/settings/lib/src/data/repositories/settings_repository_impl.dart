import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/consent_state.dart';
import '../../domain/entities/data_export_request.dart';
import '../../domain/entities/deletion_request.dart';
import '../../domain/entities/messaging_privacy.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_data_source.dart';

final class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._remote, this._session);

  final SettingsRemoteDataSource _remote;
  final SessionGateway _session;

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

  @override
  Future<Result<WhoCanMessage>> getMessagingPrivacy() =>
      _remote.getMessagingPrivacy();

  @override
  Future<Result<WhoCanMessage>> setMessagingPrivacy(WhoCanMessage value) =>
      _remote.setMessagingPrivacy(value);

  @override
  Future<Result<int>> getAvailableDiamonds() => _remote.getAvailableDiamonds();

  @override
  Future<Result<String>> submitGrievance({
    required String details,
    required IdempotencyKey idempotencyKey,
  }) async {
    final userId = _session.currentSession?.userId;
    if (userId == null) return const Err(UnauthenticatedFailure());
    return _remote.submitGrievance(
      userId: userId,
      details: details,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<Result<void>> signOut() => _session.signOut();
}
