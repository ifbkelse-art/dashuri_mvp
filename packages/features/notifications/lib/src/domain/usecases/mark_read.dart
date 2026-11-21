import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/notifications_repository.dart';

/// POST /v1/notifications/{notificationId}/read
// Not final: application tests mock use cases.
class MarkRead implements UseCase<void, String> {
  const MarkRead(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<void>> call(String input) =>
      _repository.markRead(notificationId: input);
}
