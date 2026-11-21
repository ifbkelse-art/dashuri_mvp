import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';

import '../domain/usecases/capture_moderation_frame.dart';
import '../domain/usecases/submit_moderation_frame.dart';

/// Creates a one-shot timer; injectable so tests control time.
typedef OneShotTimerFactory =
    Timer Function(Duration delay, void Function() callback);

Timer _defaultTimer(Duration d, void Function() cb) => Timer(d, cb);

/// S7 safety-check frames: while the moderation window is open, capture the
/// local outgoing camera [initialDelay] after the call becomes active and
/// then every [interval], and submit each frame. Stops at the window end, on
/// `moderation_window_closed` from the server, or on [stop].
///
/// Also stops when the server answers `accepted: false` (moderation off)
/// or 503 `moderation_not_configured`.
///
/// A failed capture or upload skips that frame (the server queues a review
/// if no frames arrive for 60 s; it never ends a call for missing frames).
final class ModerationFrameScheduler {
  ModerationFrameScheduler({
    required CaptureModerationFrame capture,
    required SubmitModerationFrame submit,
    Clock clock = const SystemClock(),
    this.initialDelay = const Duration(seconds: 5),
    this.interval = const Duration(seconds: 20),
    OneShotTimerFactory timerFactory = _defaultTimer,
  }) : _capture = capture,
       _submit = submit,
       _clock = clock,
       _timer = timerFactory;

  final CaptureModerationFrame _capture;
  final SubmitModerationFrame _submit;
  final Clock _clock;
  final OneShotTimerFactory _timer;
  final Duration initialDelay;
  final Duration interval;

  String? _callId;
  DateTime? _windowEndsAt;
  Timer? _pending;
  int _submitted = 0;

  bool get isRunning => _callId != null;

  /// Frames accepted by the server since [start].
  int get submittedCount => _submitted;

  /// Starts for [callId]; ignored when already running or the window is over.
  void start({required String callId, required DateTime windowEndsAt}) {
    if (isRunning) return;
    if (!_clock.now().isBefore(windowEndsAt)) return;
    _callId = callId;
    _windowEndsAt = windowEndsAt;
    _submitted = 0;
    _schedule(initialDelay);
  }

  void stop() {
    _pending?.cancel();
    _pending = null;
    _callId = null;
    _windowEndsAt = null;
  }

  void _schedule(Duration delay) {
    final end = _windowEndsAt;
    if (end == null || !_clock.now().add(delay).isBefore(end)) {
      stop();
      return;
    }
    _pending = _timer(delay, () => unawaited(_tick()));
  }

  Future<void> _tick() async {
    final callId = _callId;
    final end = _windowEndsAt;
    if (callId == null || end == null) return;
    if (!_clock.now().isBefore(end)) return stop();
    final frame = await _capture(const NoInput());
    if (_callId != callId) return; // stopped while capturing
    if (frame case Success(:final value)) {
      final sent = await _submit((callId: callId, frame: value));
      if (_callId != callId) return;
      switch (sent) {
        // `accepted: false`: moderation is switched off on the server.
        case Success(:final value) when !value:
          return stop();
        case Success():
          _submitted++;
        case Err(:final failure)
            when const {
              'moderation_window_closed',
              'moderation_not_configured',
            }.contains(failure.code):
          return stop();
        case Err():
          break;
      }
    }
    _schedule(interval);
  }
}
