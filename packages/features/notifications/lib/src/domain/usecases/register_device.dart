import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/notifications_repository.dart';

/// PUT /v1/me/devices
// Not final: application tests mock use cases.
class RegisterDevice
    implements UseCase<void, ({String token, String platform})> {
  const RegisterDevice(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<void>> call(({String token, String platform}) input) =>
      _repository.registerDevice(token: input.token, platform: input.platform);
}
