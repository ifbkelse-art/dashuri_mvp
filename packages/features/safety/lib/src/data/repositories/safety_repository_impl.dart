import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/age_status.dart';
import '../../domain/entities/appeal_receipt.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/entities/enforcement_notice.dart';
import '../../domain/entities/report_receipt.dart';
import '../../domain/repositories/safety_repository.dart';
import '../datasources/safety_remote_data_source.dart';

/// Default [SafetyRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class SafetyRepositoryImpl implements SafetyRepository {
  const SafetyRepositoryImpl(this._remote);

  final SafetyRemoteDataSource _remote;

  @override
  Future<Result<ReportReceipt>> reportUser({
    required String targetUserId,
    required String category,
    required String? callId,
    required String? details,
    required IdempotencyKey idempotencyKey,
  }) => _remote.reportUser(
    targetUserId: targetUserId,
    category: category,
    callId: callId,
    details: details,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<BlockedUser>> blockUser({
    required String userId,
    required IdempotencyKey idempotencyKey,
  }) => _remote.blockUser(userId: userId, idempotencyKey: idempotencyKey);

  @override
  Future<Result<void>> unblockUser({required String userId}) =>
      _remote.unblockUser(userId: userId);

  @override
  Future<Result<Page<BlockedUser>>> listBlockedUsers({
    required PageRequest page,
  }) => _remote.listBlockedUsers(page: page);

  @override
  Future<Result<AgeStatus>> getAgeStatus() => _remote.getAgeStatus();

  @override
  Future<Result<AgeStatus>> submitAgeDeclaration({
    required String dateOfBirth,
    required IdempotencyKey idempotencyKey,
  }) => _remote.submitAgeDeclaration(
    dateOfBirth: dateOfBirth,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<Page<EnforcementNotice>>> listEnforcementNotices({
    required PageRequest page,
  }) => _remote.listEnforcementNotices(page: page);

  @override
  Future<Result<AppealReceipt>> submitAppeal({
    required String enforcementId,
    required String statement,
    required IdempotencyKey idempotencyKey,
  }) => _remote.submitAppeal(
    enforcementId: enforcementId,
    statement: statement,
    idempotencyKey: idempotencyKey,
  );
}
