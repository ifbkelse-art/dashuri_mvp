import 'package:equatable/equatable.dart';

/// Server → client events (incoming call, call state change, billing tick,
/// new message). Delivered over Supabase Realtime private channels today;
/// see ADR-006. Client → server actions always go through the REST API.
final class RealtimeEvent extends Equatable {
  const RealtimeEvent({
    required this.channel,
    required this.type,
    required this.payload,
  });

  /// e.g. `user:<id>` or `call:<id>`; authorised server-side.
  final String channel;

  /// Event name, e.g. `call.state_changed`, `call.billing_tick`.
  final String type;
  final Map<String, Object?> payload;

  @override
  List<Object?> get props => [channel, type, payload];
}

/// Subscription contract. Events are hints for the UI; the REST API remains
/// the source of truth, so a missed event is recovered by re-fetching.
abstract interface class RealtimeGateway {
  Stream<RealtimeEvent> subscribe(String channel);
}
