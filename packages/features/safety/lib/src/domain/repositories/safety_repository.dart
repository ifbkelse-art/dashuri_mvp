import 'package:dashuri_core/dashuri_core.dart';

import '../entities/age_status.dart';
import '../entities/appeal_receipt.dart';
import '../entities/blocked_user.dart';
import '../entities/enforcement_notice.dart';
import '../entities/report_receipt.dart';

/// Contract for safety data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class SafetyRepository {
  Future<Result<ReportReceipt>> reportUser({
    required String targetUserId,
    required String category,
    required String? callId,
    required String? details,
    required IdempotencyKey idempotencyKey,
    // The reported host's arrival photo (2026-11-26), when the report is
    // about it.
    String? arrivalPhotoId,
  });

  Future<Result<BlockedUser>> blockUser({
    required String userId,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<void>> unblockUser({required String userId});

  Future<Result<Page<BlockedUser>>> listBlockedUsers({
    required PageRequest page,
  });

  Future<Result<AgeStatus>> getAgeStatus();

  Future<Result<AgeStatus>> submitAgeDeclaration({
    required String dateOfBirth,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<Page<EnforcementNotice>>> listEnforcementNotices({
    required PageRequest page,
  });

  Future<Result<AppealReceipt>> submitAppeal({
    required String enforcementId,
    required String statement,
    required IdempotencyKey idempotencyKey,
  });
}
