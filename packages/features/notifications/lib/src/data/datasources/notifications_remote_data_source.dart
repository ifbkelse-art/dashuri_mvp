import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/inbox_item.dart';
import '../models/inbox_item_json.dart';

/// HTTP access to the notifications endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class NotificationsRemoteDataSource {
  const NotificationsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<void>> registerDevice({
    required String token,
    required String platform,
  }) => _api.put(
    '/v1/me/devices',
    decode: (_) {},
    body: {'token': token, 'platform': platform},
  );

  Future<Result<void>> unregisterDevice({required String token}) =>
      _api.delete('/v1/me/devices/$token');

  Future<Result<Page<InboxItem>>> listInbox({required PageRequest page}) =>
      _api.get(
        '/v1/notifications',
        decode: pageDecoder(inboxItemFromJson),
        query: page.toQuery(),
      );

  Future<Result<void>> markRead({required String notificationId}) =>
      _api.post('/v1/notifications/$notificationId/read', decode: (_) {});
}
