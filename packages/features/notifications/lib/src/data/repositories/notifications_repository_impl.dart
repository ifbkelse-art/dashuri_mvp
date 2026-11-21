import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/inbox_item.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_realtime_source.dart';
import '../datasources/notifications_remote_data_source.dart';

/// Default [NotificationsRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this._remote, this._realtime);

  final NotificationsRemoteDataSource _remote;
  final NotificationsRealtimeSource _realtime;

  @override
  Stream<void> watchNewNotifications() => _realtime.watch();

  @override
  Future<Result<void>> registerDevice({
    required String token,
    required String platform,
  }) => _remote.registerDevice(token: token, platform: platform);

  @override
  Future<Result<void>> unregisterDevice({required String token}) =>
      _remote.unregisterDevice(token: token);

  @override
  Future<Result<Page<InboxItem>>> listInbox({required PageRequest page}) =>
      _remote.listInbox(page: page);

  @override
  Future<Result<void>> markRead({required String notificationId}) =>
      _remote.markRead(notificationId: notificationId);
}
