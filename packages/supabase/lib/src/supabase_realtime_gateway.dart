import 'dart:async';

import 'package:dashuri_network/dashuri_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Subscribes to PRIVATE Supabase Realtime broadcast channels. Channel access
/// is authorised by Realtime Authorization policies (see
/// docs/architecture/database-architecture.md). The Go backend publishes.
final class SupabaseRealtimeGateway implements RealtimeGateway {
  SupabaseRealtimeGateway(this._client);

  final sb.SupabaseClient _client;

  @override
  Stream<RealtimeEvent> subscribe(String channel) {
    late final sb.RealtimeChannel ch;
    // Closed by the subscriber cancelling (onCancel removes the channel).
    // ignore: close_sinks
    final controller = StreamController<RealtimeEvent>(
      onCancel: () async {
        await _client.removeChannel(ch);
      },
    );
    ch = _client
        .channel(channel, opts: const sb.RealtimeChannelConfig(private: true))
        .onBroadcast(
          event: '*',
          callback: (payload) {
            final type = payload['event'];
            final data = payload['payload'];
            controller.add(
              RealtimeEvent(
                channel: channel,
                type: type is String ? type : 'unknown',
                payload: data is Map<String, Object?> ? data : const {},
              ),
            );
          },
        )
        .subscribe();
    return controller.stream;
  }
}
