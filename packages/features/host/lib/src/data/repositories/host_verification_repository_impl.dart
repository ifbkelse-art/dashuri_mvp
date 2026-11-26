import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/host_photo.dart';
import '../../domain/entities/host_verification.dart';
import '../../domain/repositories/host_verification_repository.dart';
import '../datasources/host_verification_remote_data_source.dart';
import '../datasources/photo_upload_data_source.dart';

final class HostVerificationRepositoryImpl
    implements HostVerificationRepository {
  const HostVerificationRepositoryImpl(this._remote, this._upload);

  final HostVerificationRemoteDataSource _remote;
  final PhotoUploadDataSource _upload;

  @override
  Future<Result<HostVerification>> getVerification() => _remote.get();

  @override
  Future<Result<void>> uploadEvidence({
    required EvidenceKind kind,
    required PickedPhoto media,
  }) async {
    final ticket = await _remote.createUpload(
      kind: kind,
      contentType: media.contentType,
    );
    return switch (ticket) {
      Err(:final failure) => Err(failure),
      Success(:final value) => await _upload.upload(
        ticket: value,
        photo: media,
      ),
    };
  }

  @override
  Future<Result<HostVerification>> submit({
    required List<String> evidenceIds,
    required IdempotencyKey idempotencyKey,
  }) =>
      _remote.submit(evidenceIds: evidenceIds, idempotencyKey: idempotencyKey);
}
