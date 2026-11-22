import 'dart:async';

import 'package:dashuri_network/dashuri_network.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Opens one Realtime channel for [topic] and reports each broadcast to
/// [onEvent]. Returns a function that closes the channel.
@visibleForTesting
typedef RealtimeChannelOpener =
    Future<void> Function() Function(
      String topic,
      void Function(String type, Map<String, Object?> payload) onEvent,
    );

/// Subscribes to PRIVATE Supabase Realtime broadcast channels. Channel access
/// is authorised by Realtime Authorization policies (see
/// docs/architecture/database-architecture.md). The Go backend publishes.
///
/// Several features listen to the same topic (chat, wallet, calls and
/// notifications all use `user:<id>`). Realtime allows one join per topic on
/// a socket: a second join makes the server close the first, and the client
/// then drops that channel for good. So this gateway opens ONE channel per
/// topic and fans its events out to every subscriber, closing the channel
/// when the last subscriber cancels.
final class SupabaseRealtimeGateway implements RealtimeGateway {
  SupabaseRealtimeGateway(sb.SupabaseClient client)
    : _open = _supabaseOpener(client);

  @visibleForTesting
  SupabaseRealtimeGateway.withOpener(this._open);

  final RealtimeChannelOpener _open;
  final Map<String, _SharedTopic> _topics = {};

  @override
  Stream<RealtimeEvent> subscribe(String channel) {
    // Closed by the subscriber cancelling (onCancel releases the topic).
    // ignore: close_sinks
    late final StreamController<RealtimeEvent> controller;
    controller = StreamController<RealtimeEvent>(
      onListen: () {
        final shared = _topics.putIfAbsent(
          channel,
          () => _SharedTopic(channel, _open),
        );
        shared.listeners.add(controller);
      },
      onCancel: () async {
        final shared = _topics[channel];
        if (shared == null) return;
        shared.listeners.remove(controller);
        if (shared.listeners.isEmpty) {
          _topics.remove(channel);
          await shared.close();
        }
      },
    );
    return controller.stream;
  }

  static RealtimeChannelOpener _supabaseOpener(sb.SupabaseClient client) =>
      (topic, onEvent) {
        final ch = client
            .channel(topic, opts: const sb.RealtimeChannelConfig(private: true))
            .onBroadcast(
              event: '*',
              callback: (payload) {
                final type = payload['event'];
                final data = payload['payload'];
                onEvent(
                  type is String ? type : 'unknown',
                  data is Map<String, Object?> ? data : const {},
                );
              },
            )
            .subscribe();
        return () => client.removeChannel(ch);
      };
}

final class _SharedTopic {
  _SharedTopic(this.topic, RealtimeChannelOpener open) {
    _close = open(topic, (type, payload) {
      final event = RealtimeEvent(channel: topic, type: type, payload: payload);
      // Copy: a listener may cancel while we deliver.
      for (final l in List.of(listeners)) {
        if (!l.isClosed) l.add(event);
      }
    });
  }

  final String topic;
  final List<StreamController<RealtimeEvent>> listeners = [];
  late final Future<void> Function() _close;

  Future<void> close() => _close();
}
