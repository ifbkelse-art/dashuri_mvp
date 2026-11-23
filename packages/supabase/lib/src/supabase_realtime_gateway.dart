import 'dart:async';
import 'dart:math' as math;

import 'package:dashuri_network/dashuri_network.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Opens one Realtime channel for [topic], reports each broadcast to
/// [onEvent] and the channel's health to [onLink] (`up: true` once joined,
/// `up: false` when the client gave the channel up for good). Returns a
/// function that closes the channel.
@visibleForTesting
typedef RealtimeChannelOpener =
    Future<void> Function() Function(
      String topic,
      void Function(String type, Map<String, Object?> payload) onEvent,
      void Function({required bool up}) onLink,
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
///
/// A channel the server closes (token renewal, network loss, a duplicate
/// join) is dropped for good by the client, which would silently stop
/// incoming calls until the app restarts. While anyone still listens, the
/// gateway reopens it, waiting [reopenDelay] and doubling up to
/// [maxReopenDelay] while it keeps failing.
final class SupabaseRealtimeGateway implements RealtimeGateway {
  SupabaseRealtimeGateway(sb.SupabaseClient client)
    : _open = _supabaseOpener(client),
      reopenDelay = const Duration(seconds: 2),
      maxReopenDelay = const Duration(seconds: 60);

  @visibleForTesting
  SupabaseRealtimeGateway.withOpener(
    this._open, {
    this.reopenDelay = const Duration(seconds: 2),
    this.maxReopenDelay = const Duration(seconds: 60),
  });

  final RealtimeChannelOpener _open;
  final Duration reopenDelay;
  final Duration maxReopenDelay;
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
          () => _SharedTopic(channel, _open, reopenDelay, maxReopenDelay),
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
      (topic, onEvent, onLink) {
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
            .subscribe((status, _) {
              switch (status) {
                case sb.RealtimeSubscribeStatus.subscribed:
                  onLink(up: true);
                // The client retries errors and timeouts itself; a closed
                // channel is removed from the socket and never rejoins.
                case sb.RealtimeSubscribeStatus.closed:
                  onLink(up: false);
                case sb.RealtimeSubscribeStatus.channelError ||
                    sb.RealtimeSubscribeStatus.timedOut:
                  break;
              }
            });
        return () => client.removeChannel(ch);
      };
}

final class _SharedTopic {
  _SharedTopic(this.topic, this._open, this._baseDelay, this._maxDelay) {
    _connect();
  }

  final String topic;
  final RealtimeChannelOpener _open;
  final Duration _baseDelay;
  final Duration _maxDelay;
  final List<StreamController<RealtimeEvent>> listeners = [];

  Future<void> Function()? _closeChannel;
  Timer? _reopen;
  int _failures = 0;
  bool _closed = false;

  void _connect() {
    // Each channel instance gets its own generation so a late "closed" from
    // a channel we already replaced is ignored.
    final generation = Object();
    _generation = generation;
    _closeChannel = _open(
      topic,
      (type, payload) {
        final event = RealtimeEvent(
          channel: topic,
          type: type,
          payload: payload,
        );
        // Copy: a listener may cancel while we deliver.
        for (final l in List.of(listeners)) {
          if (!l.isClosed) l.add(event);
        }
      },
      ({required up}) {
        if (_closed || !identical(_generation, generation)) return;
        if (up) {
          _failures = 0;
        } else {
          _scheduleReopen();
        }
      },
    );
  }

  Object? _generation;

  void _scheduleReopen() {
    if (_reopen != null) return;
    final ms = math.min(
      _baseDelay.inMilliseconds * math.pow(2, _failures).toInt(),
      _maxDelay.inMilliseconds,
    );
    _failures++;
    _reopen = Timer(Duration(milliseconds: ms), () async {
      _reopen = null;
      if (_closed) return;
      final old = _closeChannel;
      _generation = null; // ignore the old channel's final callbacks
      await old?.call();
      if (_closed) return;
      _connect();
    });
  }

  Future<void> close() async {
    _closed = true;
    _reopen?.cancel();
    _reopen = null;
    await _closeChannel?.call();
  }
}
