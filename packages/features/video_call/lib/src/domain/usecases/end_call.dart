import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_session.dart';
import '../repositories/call_repository.dart';

// Not final: application tests mock use cases.
class EndCall
    implements
        UseCase<
          CallSession,
          ({String callId, String reason, IdempotencyKey idempotencyKey})
        > {
  const EndCall(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<CallSession>> call(
    ({String callId, String reason, IdempotencyKey idempotencyKey}) input,
  ) => _repository.endCall(
    callId: input.callId,
    reason: input.reason,
    idempotencyKey: input.idempotencyKey,
  );
}
