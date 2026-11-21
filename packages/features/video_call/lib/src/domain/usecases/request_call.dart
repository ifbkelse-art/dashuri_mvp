import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_session.dart';
import '../repositories/call_repository.dart';

// Not final: application tests mock use cases.
class RequestCall
    implements
        UseCase<
          CallSession,
          ({String hostUserId, IdempotencyKey idempotencyKey})
        > {
  const RequestCall(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<CallSession>> call(
    ({String hostUserId, IdempotencyKey idempotencyKey}) input,
  ) => _repository.requestCall(
    hostUserId: input.hostUserId,
    idempotencyKey: input.idempotencyKey,
  );
}
