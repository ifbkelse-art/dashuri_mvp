import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_photo.dart';
import '../../domain/entities/host_verification.dart';
import '../models/host_verification_json.dart';

/// HTTP access to the Verified Host endpoints (2026-11-23).
final class HostVerificationRemoteDataSource {
  const HostVerificationRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<HostVerification>> get() => _api.get(
    '/v1/host/verification',
    decode: objectDecoder(hostVerificationFromJson),
  );

  /// POST /v1/host/verification/evidence → signed upload URL (private bucket).
  Future<Result<PhotoUploadTicket>> createUpload({
    required EvidenceKind kind,
    required String contentType,
  }) => _api.post(
    '/v1/host/verification/evidence',
    body: {'kind': kind.wire, 'content_type': contentType},
    decode: objectDecoder(
      (j) => PhotoUploadTicket(
        photoId: j['evidence_id']! as String,
        uploadUrl: Uri.parse(j['upload_url']! as String),
        expiresAt: DateTime.parse(j['expires_at']! as String),
      ),
    ),
  );

  Future<Result<HostVerification>> submit({
    required List<String> evidenceIds,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/host/verification/submissions',
    body: {'evidence_ids': evidenceIds},
    idempotencyKey: idempotencyKey,
    decode: objectDecoder(hostVerificationFromJson),
  );
}
