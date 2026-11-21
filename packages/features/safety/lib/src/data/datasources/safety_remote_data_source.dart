import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/age_status.dart';
import '../../domain/entities/appeal_receipt.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/entities/enforcement_notice.dart';
import '../../domain/entities/report_receipt.dart';
import '../models/age_status_json.dart';
import '../models/appeal_receipt_json.dart';
import '../models/blocked_user_json.dart';
import '../models/enforcement_notice_json.dart';
import '../models/report_receipt_json.dart';

/// HTTP access to the safety endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class SafetyRemoteDataSource {
  const SafetyRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<ReportReceipt>> reportUser({
    required String targetUserId,
    required String category,
    required String? callId,
    required String? details,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/reports',
    decode: objectDecoder(reportReceiptFromJson),
    body: {
      'target_user_id': targetUserId,
      'category': category,
      'call_id': ?callId,
      'details': ?details,
    },
    idempotencyKey: idempotencyKey,
  );

  Future<Result<BlockedUser>> blockUser({
    required String userId,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/blocks',
    decode: objectDecoder(blockedUserFromJson),
    body: {'user_id': userId},
    idempotencyKey: idempotencyKey,
  );

  Future<Result<void>> unblockUser({required String userId}) =>
      _api.delete('/v1/blocks/$userId');

  Future<Result<Page<BlockedUser>>> listBlockedUsers({
    required PageRequest page,
  }) => _api.get(
    '/v1/blocks',
    decode: pageDecoder(blockedUserFromJson),
    query: page.toQuery(),
  );

  Future<Result<AgeStatus>> getAgeStatus() =>
      _api.get('/v1/me/age', decode: objectDecoder(ageStatusFromJson));

  Future<Result<AgeStatus>> submitAgeDeclaration({
    required String dateOfBirth,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/me/age/declaration',
    decode: objectDecoder(ageStatusFromJson),
    body: {'date_of_birth': dateOfBirth},
    idempotencyKey: idempotencyKey,
  );

  Future<Result<Page<EnforcementNotice>>> listEnforcementNotices({
    required PageRequest page,
  }) => _api.get(
    '/v1/me/enforcement',
    decode: pageDecoder(enforcementNoticeFromJson),
    query: page.toQuery(),
  );

  Future<Result<AppealReceipt>> submitAppeal({
    required String enforcementId,
    required String statement,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/appeals',
    decode: objectDecoder(appealReceiptFromJson),
    body: {'enforcement_id': enforcementId, 'statement': statement},
    idempotencyKey: idempotencyKey,
  );
}
