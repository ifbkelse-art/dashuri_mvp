import 'package:dashuri_core/dashuri_core.dart';

import '../entities/messaging_privacy.dart';
import '../repositories/chat_repository.dart';

/// PUT /v1/me/messaging-privacy
// Not final: application tests mock use cases.
class UpdateMessagingPrivacy implements UseCase<MessagingPrivacy, String> {
  const UpdateMessagingPrivacy(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<MessagingPrivacy>> call(String input) =>
      _repository.updateMessagingPrivacy(whoCanMessage: input);
}
