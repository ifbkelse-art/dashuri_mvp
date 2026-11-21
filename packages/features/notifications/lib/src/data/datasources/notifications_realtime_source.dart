import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

/// Subscribes to the signed-in user's private channel and filters
/// `notification.created` hints.
final class NotificationsRealtimeSource {
  const NotificationsRealtimeSource(this._realtime, this._session);

  static const eventType = 'notification.created';

  final RealtimeGateway _realtime;
  final SessionGateway _session;

  Stream<void> watch() {
    final userId = _session.currentSession?.userId;
    if (userId == null) return const Stream.empty();
    return _realtime
        .subscribe('user:$userId')
        .where((e) => e.type == eventType)
        .map((_) {});
  }
}
