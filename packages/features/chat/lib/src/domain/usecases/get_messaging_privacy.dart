import 'package:dashuri_core/dashuri_core.dart';

import '../entities/messaging_privacy.dart';
import '../repositories/chat_repository.dart';

/// GET /v1/me/messaging-privacy
// Not final: application tests mock use cases.
class GetMessagingPrivacy implements UseCase<MessagingPrivacy, NoInput> {
  const GetMessagingPrivacy(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<MessagingPrivacy>> call(NoInput input) =>
      _repository.getMessagingPrivacy();
}
