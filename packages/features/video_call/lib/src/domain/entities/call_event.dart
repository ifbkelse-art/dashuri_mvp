import 'package:equatable/equatable.dart';

import 'call_session.dart';

/// Server events for one call (realtime channel `call:<id>`).
sealed class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

/// The server's view of the call changed; replace local state with [session].
final class CallUpdated extends CallEvent {
  const CallUpdated(this.session);

  final CallSession session;

  @override
  List<Object?> get props => [session];
}

/// The customer's balance covers about [secondsRemaining] more seconds.
/// Sent ~30 s before exhaustion (founder decision S6).
final class CallLowBalance extends CallEvent {
  const CallLowBalance(this.secondsRemaining);

  final int secondsRemaining;

  @override
  List<Object?> get props => [secondsRemaining];
}

/// The automated safety check ended the call (S7). A `call.updated` with
/// the final state follows; this only lets the UI explain why.
final class CallModerationEnded extends CallEvent {
  const CallModerationEnded();
}
