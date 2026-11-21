import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/chat_repository.dart';

/// POST /v1/conversations/{conversationId}/read
// Not final: application tests mock use cases.
class MarkConversationRead implements UseCase<void, String> {
  const MarkConversationRead(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<void>> call(String conversationId) =>
      _repository.markRead(conversationId);
}

/// `chat.message` realtime hints (conversation ids).
// Not final: application tests mock use cases.
class WatchChatHints implements StreamUseCase<String, NoInput> {
  const WatchChatHints(this._repository);

  final ChatRepository _repository;

  @override
  Stream<String> call(NoInput input) => _repository.chatHints();
}

/// The signed-in user's id, or `unauthenticated`.
// Not final: application tests mock use cases.
class GetCurrentUserId implements UseCase<String, NoInput> {
  const GetCurrentUserId(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<String>> call(NoInput input) async {
    final id = _repository.currentUserId();
    return id == null ? const Err(UnauthenticatedFailure()) : Success(id);
  }
}
