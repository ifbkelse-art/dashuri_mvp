import 'package:dashuri_core/dashuri_core.dart';

import '../entities/report_receipt.dart';
import '../repositories/safety_repository.dart';

/// POST /v1/reports
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class ReportUser
    implements
        UseCase<
          ReportReceipt,
          ({
            String targetUserId,
            String category,
            String? callId,
            String? details,
            IdempotencyKey idempotencyKey,
          })
        > {
  const ReportUser(this._repository);

  final SafetyRepository _repository;

  @override
  Future<Result<ReportReceipt>> call(
    ({
      String targetUserId,
      String category,
      String? callId,
      String? details,
      IdempotencyKey idempotencyKey,
    })
    input,
  ) => _repository.reportUser(
    targetUserId: input.targetUserId,
    category: input.category,
    callId: input.callId,
    details: input.details,
    idempotencyKey: input.idempotencyKey,
  );
}
