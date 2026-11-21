import 'package:dashuri_core/dashuri_core.dart';

import '../entities/inbox_item.dart';

/// Contract for notifications data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class NotificationsRepository {
  Future<Result<void>> registerDevice({
    required String token,
    required String platform,
  });

  Future<Result<void>> unregisterDevice({required String token});

  Future<Result<Page<InboxItem>>> listInbox({required PageRequest page});

  Future<Result<void>> markRead({required String notificationId});

  /// Hints from realtime (`user:<id>` `notification.created`). Each event
  /// means "re-fetch the inbox"; the API stays the source of truth.
  Stream<void> watchNewNotifications();
}
