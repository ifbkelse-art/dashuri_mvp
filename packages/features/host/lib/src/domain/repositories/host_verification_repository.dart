import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_photo.dart';
import '../entities/host_verification.dart';

/// Verified Host application (separate from [HostRepository] so existing
/// implementations stay unchanged).
abstract interface class HostVerificationRepository {
  Future<Result<HostVerification>> getVerification();

  /// Gets a signed upload URL for [kind], then PUTs the bytes to it.
  Future<Result<void>> uploadEvidence({
    required EvidenceKind kind,
    required PickedPhoto media,
  });

  Future<Result<HostVerification>> submit({
    required List<String> evidenceIds,
    required IdempotencyKey idempotencyKey,
  });
}
