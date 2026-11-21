import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/notifications_repository.dart';

// Not final: application tests mock use cases.
class WatchNewNotifications implements StreamUseCase<void, NoInput> {
  const WatchNewNotifications(this._repository);

  final NotificationsRepository _repository;

  @override
  Stream<void> call(NoInput input) => _repository.watchNewNotifications();
}
