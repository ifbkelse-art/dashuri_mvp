import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/notifications_repository.dart';

/// DELETE /v1/me/devices/{token}
// Not final: application tests mock use cases.
class UnregisterDevice implements UseCase<void, String> {
  const UnregisterDevice(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<void>> call(String input) =>
      _repository.unregisterDevice(token: input);
}
