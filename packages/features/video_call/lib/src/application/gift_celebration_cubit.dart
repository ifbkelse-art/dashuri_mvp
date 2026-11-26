import 'dart:async';
import 'dart:collection';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/gift.dart';
import '../domain/usecases/gift_usecases.dart';

/// Creates a one-shot timer (injected so tests drive time).
typedef GiftTimerFactory = Timer Function(Duration d, void Function() onDone);

final class GiftCelebrationState extends Equatable {
  const GiftCelebrationState({
    this.current,
    this.pending = 0,
    this.compact = false,
    this.sequence = 0,
  });

  /// The gift being celebrated now (one major celebration at a time).
  final GiftEvent? current;

  /// Gifts waiting their turn.
  final int pending;

  /// The queue is long: celebrations are shortened so none is dropped.
  final bool compact;

  /// Increments per celebration shown.
  final int sequence;

  @override
  List<Object?> get props => [current, pending, compact, sequence];
}

/// Orders gift celebrations for one call.
///
/// - Only server-confirmed gifts are celebrated: the `call.gift` realtime
///   event, the sender's own receipt, or the canonical history fetched after
///   a reconnect. A tap on Send never animates by itself.
/// - Every gift is shown once (deduplicated by gift transaction id), one at
///   a time, in arrival order.
/// - Gifts that existed when the call screen opened are history, not news:
///   they are marked seen without a celebration, and so are gifts older than
///   [freshFor] found after a reconnect.
/// - The queue is never silently trimmed: above [compactAbove] waiting
///   gifts, each celebration is shortened to [compactDuration].
/// - Celebrations are cosmetic: a failure here never affects the gift, which
///   is already recorded server-side.
final class GiftCelebrationCubit extends Cubit<GiftCelebrationState> {
  GiftCelebrationCubit({
    required GetCallGifts history,
    required WatchCallGifts watch,
    GiftTimerFactory? timer,
    DateTime Function()? now,
    this.freshFor = const Duration(seconds: 20),
    this.compactAbove = 5,
    this.compactDuration = const Duration(milliseconds: 1500),
  }) : _history = history,
       _watch = watch,
       _timer = timer ?? ((d, f) => Timer(d, f)),
       _now = now ?? (() => DateTime.now().toUtc()),
       super(const GiftCelebrationState());

  final GetCallGifts _history;
  final WatchCallGifts _watch;
  final GiftTimerFactory _timer;
  final DateTime Function() _now;
  final Duration freshFor;
  final int compactAbove;
  final Duration compactDuration;

  final _seen = <String>{};
  final _queue = Queue<GiftEvent>();
  StreamSubscription<GiftEvent>? _sub;
  Timer? _showing;
  String? _callId;

  /// Starts watching [callId]. Existing gifts are marked seen (no replay).
  Future<void> start(String callId) async {
    if (_callId != null) return;
    _callId = callId;
    _sub = _watch(callId).listen(offer, onError: (Object _) {});
    final r = await _history(callId);
    if (r case Success(:final value)) {
      // Gifts already in the history when the screen opened are history;
      // anything that arrived over realtime meanwhile was already offered.
      for (final g in value) {
        _seen.add(g.giftTransactionId);
      }
    }
  }

  /// After a reconnect: gifts missed while offline are fetched from the
  /// canonical history; recent ones are celebrated, older ones only marked.
  Future<void> resync() async {
    final callId = _callId;
    if (callId == null || isClosed) return;
    final r = await _history(callId);
    if (r case Success(:final value)) {
      final now = _now();
      for (final g in value) {
        if (_seen.contains(g.giftTransactionId)) continue;
        if (now.difference(g.sentAt) <= freshFor) {
          offer(g);
        } else {
          _seen.add(g.giftTransactionId);
        }
      }
    }
  }

  /// Offers a server-confirmed gift. Duplicates are ignored.
  void offer(GiftEvent gift) {
    if (isClosed || !_seen.add(gift.giftTransactionId)) return;
    if (_callId != null && gift.callId != _callId) return;
    _queue.add(gift);
    if (state.current == null) {
      _next();
    } else {
      _emitQueue();
    }
  }

  /// The overlay reports that it could not render (or finished early).
  void finished() {
    if (state.current == null) return;
    _showing?.cancel();
    _next();
  }

  void _emitQueue() => emit(
    GiftCelebrationState(
      current: state.current,
      pending: _queue.length,
      compact: _queue.length >= compactAbove,
      sequence: state.sequence,
    ),
  );

  void _next() {
    if (isClosed) return;
    if (_queue.isEmpty) {
      emit(GiftCelebrationState(sequence: state.sequence));
      return;
    }
    final gift = _queue.removeFirst();
    final compact = _queue.length >= compactAbove;
    emit(
      GiftCelebrationState(
        current: gift,
        pending: _queue.length,
        compact: compact,
        sequence: state.sequence + 1,
      ),
    );
    _showing = _timer(
      compact ? compactDuration : gift.animationDuration,
      _next,
    );
  }

  @override
  Future<void> close() async {
    _showing?.cancel();
    await _sub?.cancel();
    return super.close();
  }
}
