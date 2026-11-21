import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_storage/dashuri_storage.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';

/// [ExperienceController] backed by [KeyValueStore], kept per user id.
/// Follows the [SessionCubit]: it reloads the stored choices when a
/// different user signs in and tracks whether host mode is available
/// (approved host, from `GET /v1/me`).
final class AppExperienceController extends ChangeNotifier
    implements ExperienceController {
  AppExperienceController(this._store);

  static String permissionsKey(String userId) =>
      'onboarding.permissions_primer.$userId';
  static String modeKey(String userId) => 'experience.mode.$userId';

  final KeyValueStore _store;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  StreamSubscription<SessionState>? _subscription;

  String? _userId;
  bool _loaded = false;
  bool _primerDone = false;
  ExperienceMode? _mode;
  bool _hostModeAvailable = false;

  /// Starts following [session] (current state included).
  void bind(SessionCubit session) {
    unawaited(_subscription?.cancel());
    _subscription = session.stream.listen(onSession);
    unawaited(onSession(session.state));
  }

  /// Applies a session state. Public for tests.
  Future<void> onSession(SessionState state) async {
    switch (state) {
      case SessionSignedIn(:final session, :final account):
        final available = account?.isApprovedHost ?? false;
        if (session.userId != _userId) {
          _userId = session.userId;
          _loaded = false;
          _hostModeAvailable = available;
          _notify();
          await _load(session.userId);
        } else if (available != _hostModeAvailable) {
          _hostModeAvailable = available;
          _notify();
        }
      case SessionSignedOut() || SessionUnknown():
        if (_userId != null || _loaded) {
          _userId = null;
          _loaded = false;
          _primerDone = false;
          _mode = null;
          _hostModeAvailable = false;
          _notify();
        }
    }
  }

  Future<void> _load(String userId) async {
    String? primer;
    String? mode;
    try {
      primer = await _store.read(permissionsKey(userId));
      mode = await _store.read(modeKey(userId));
    } on Exception {
      // Unreadable preferences: treat as a fresh device (onboarding again).
    }
    if (_userId != userId) return;
    _primerDone = primer == '1';
    _mode = ExperienceMode.values.where((m) => m.name == mode).firstOrNull;
    _loaded = true;
    _notify();
  }

  @override
  bool get isLoaded => _loaded;

  @override
  bool get permissionsPrimerDone => _primerDone;

  @override
  ExperienceMode? get mode => _mode;

  @override
  bool get hostModeAvailable => _hostModeAvailable;

  @override
  ExperienceMode get effectiveMode =>
      _mode == ExperienceMode.host && _hostModeAvailable
      ? ExperienceMode.host
      : ExperienceMode.customer;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> completePermissionsPrimer() async {
    final id = _userId;
    _primerDone = true;
    _notify();
    if (id != null) await _safeWrite(permissionsKey(id), '1');
  }

  @override
  Future<void> setMode(ExperienceMode mode) async {
    final id = _userId;
    _mode = mode;
    _notify();
    if (id != null) await _safeWrite(modeKey(id), mode.name);
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _store.write(key, value);
    } on Exception {
      // Kept in memory for this run; asked again after a restart.
    }
  }

  void _notify() {
    notifyListeners();
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_changes.close());
    super.dispose();
  }
}
