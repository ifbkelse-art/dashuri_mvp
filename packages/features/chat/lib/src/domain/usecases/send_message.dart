import 'package:dashuri_core/dashuri_core.dart';

import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// POST /v1/conversations/{conversationId}/messages
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class SendMessage
    implements
        UseCase<
          ChatMessage,
          ({String conversationId, String body, IdempotencyKey idempotencyKey})
        > {
  const SendMessage(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<ChatMessage>> call(
    ({String conversationId, String body, IdempotencyKey idempotencyKey}) input,
  ) => _repository.sendMessage(
    conversationId: input.conversationId,
    body: input.body,
    idempotencyKey: input.idempotencyKey,
  );
}
