import 'package:dashuri_core/dashuri_core.dart';

import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// GET /v1/conversations/{conversationId}/messages
///
/// With `callId`: that call's in-call session chat only. Without it: normal
/// Chat (a live call's session joins it when the call ends).
// Not final: application tests mock use cases.
class ListMessages
    implements
        UseCase<
          Page<ChatMessage>,
          ({String conversationId, PageRequest page, String? callId})
        > {
  const ListMessages(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<Page<ChatMessage>>> call(
    ({String conversationId, PageRequest page, String? callId}) input,
  ) => _repository.listMessages(
    conversationId: input.conversationId,
    page: input.page,
    callId: input.callId,
  );
}
