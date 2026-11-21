import 'package:dashuri_core/dashuri_core.dart';

import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

/// POST /v1/conversations
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class StartConversation
    implements
        UseCase<
          Conversation,
          ({String peerUserId, IdempotencyKey idempotencyKey})
        > {
  const StartConversation(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<Conversation>> call(
    ({String peerUserId, IdempotencyKey idempotencyKey}) input,
  ) => _repository.startConversation(
    peerUserId: input.peerUserId,
    idempotencyKey: input.idempotencyKey,
  );
}
