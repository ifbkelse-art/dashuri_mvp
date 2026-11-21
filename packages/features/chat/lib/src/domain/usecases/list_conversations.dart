import 'package:dashuri_core/dashuri_core.dart';

import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

/// GET /v1/conversations
// Not final: application tests mock use cases.
class ListConversations implements UseCase<Page<Conversation>, PageRequest> {
  const ListConversations(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<Page<Conversation>>> call(PageRequest input) =>
      _repository.listConversations(page: input);
}
