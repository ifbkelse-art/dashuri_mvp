import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:flutter/widgets.dart';

import '../domain/usecases/send_heartbeat.dart';

/// Creates a periodic timer. Injected so tests drive heartbeats with a fake
/// clock instead of waiting 30 s.
typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer timer) onTick);

/// Keeps an online host listed by sending POST /v1/host/availability/heartbeat
/// every [interval] while the host is online AND the app is in the
/// foreground. App-wide singleton (registered lazily in DI) so every host
/// screen shares one timer.
///
/// - [setOnline] is called by cubits after the server confirms availability.
/// - [attachLifecycle] installs an [AppLifecycleListener]: heartbeats stop
///   when the app is paused or hidden and resume (with one immediate beat)
///   when it returns. The server marks a silent host offline by itself.
/// - A heartbeat refused by the server (403/409) stops the timer and is
///   published on [heartbeatRejected] so the dashboard re-reads its status.
class HostPresenceController {
  HostPresenceController(
    this._sendHeartbeat, {
    PeriodicTimerFactory? timerFactory,
    this.interval = const Duration(seconds: 30),
  }) : _timerFactory = timerFactory ?? Timer.periodic;

  final SendHeartbeat _sendHeartbeat;
  final PeriodicTimerFactory _timerFactory;
  final Duration interval;

  final _rejected = StreamController<Failure>.broadcast();
  final _incoming = StreamController<String>.broadcast();
  final _network = StreamController<bool>.broadcast();
  int _networkFailures = 0;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool _online = false;
  bool _foreground = true;

  Stream<Failure> get heartbeatRejected => _rejected.stream;

  /// Ringing calls for this host, reported by the app's incoming-call
  /// watcher BEFORE it opens the call screen, so Host Home shows the ring
  /// at once (2026-11-26).
  Stream<String> get incomingCalls => _incoming.stream;

  /// Heartbeat reachability while online: false after a heartbeat failed for
  /// network reasons, true again after the next success.
  Stream<bool> get networkHealthy => _network.stream;

  /// Consecutive heartbeat network failures (0 when healthy).
  int get networkFailures => _networkFailures;

  /// Sends one heartbeat now (e.g. "Retry" after a network problem).
  Future<void> beatNow() => _beat();

  /// Called by the app when a call rings for this host.
  void notifyIncomingCall(String callId) {
    if (!_incoming.isClosed) _incoming.add(callId);
  }

  bool get isOnline => _online;
  bool get isInForeground => _foreground;
  bool get isBeating => _timer != null;

  void setOnline({required bool online}) {
    _online = online;
    _sync();
  }

  void appPaused() {
    _foreground = false;
    _sync();
  }

  void appResumed() {
    final wasBackground = !_foreground;
    _foreground = true;
    _sync();
    if (wasBackground && _online) unawaited(_beat());
  }

  /// Idempotent. Requires a [WidgetsBinding] (call from a widget).
  void attachLifecycle() {
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) => switch (state) {
        AppLifecycleState.resumed => appResumed(),
        AppLifecycleState.paused ||
        AppLifecycleState.hidden ||
        AppLifecycleState.detached => appPaused(),
        AppLifecycleState.inactive => null,
      },
    );
  }

  void _sync() {
    final shouldBeat = _online && _foreground;
    if (shouldBeat && _timer == null) {
      _timer = _timerFactory(interval, (_) => unawaited(_beat()));
    } else if (!shouldBeat && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  Future<void> _beat() async {
    final result = await _sendHeartbeat(const NoInput());
    if (result is Success) {
      if (_networkFailures > 0 && !_network.isClosed) _network.add(true);
      _networkFailures = 0;
    }
    if (result case Err(:final failure)) {
      if (failure is NetworkFailure) {
        _networkFailures++;
        if (!_network.isClosed) _network.add(false);
      }
      final refused =
          failure is ForbiddenFailure ||
          failure is BusinessRuleFailure ||
          failure is ConflictFailure;
      if (refused) {
        _online = false;
        _sync();
        _rejected.add(failure);
      }
      // Network failures are ignored: the next tick retries.
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    await _rejected.close();
    await _incoming.close();
    await _network.close();
  }
}
