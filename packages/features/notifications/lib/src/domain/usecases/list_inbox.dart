import 'package:dashuri_core/dashuri_core.dart';

import '../entities/inbox_item.dart';
import '../repositories/notifications_repository.dart';

/// GET /v1/notifications
// Not final: application tests mock use cases.
class ListInbox implements UseCase<Page<InboxItem>, PageRequest> {
  const ListInbox(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<Result<Page<InboxItem>>> call(PageRequest input) =>
      _repository.listInbox(page: input);
}
