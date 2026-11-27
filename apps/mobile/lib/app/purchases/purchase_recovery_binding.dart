import 'dart:async';

import 'package:feature_auth/feature_auth.dart';

/// Runs Google Play purchase recovery (`PurchaseRecovery.run`) at the right
/// moments for the whole app, not only while the purchase screen is open:
///
/// - once each time a user signs in (including a restored session at start);
/// - every time the app returns to the foreground while signed in.
///
/// A purchase paid while the app was killed is then credited on the next
/// launch. Errors are swallowed: the next start or resume retries.
final class PurchaseRecoveryBinding {
  PurchaseRecoveryBinding(this._recover);

  final Future<int> Function() _recover;
  StreamSubscription<SessionState>? _subscription;
  String? _userId;

  /// Follows [changes], applying [current] first.
  void bind(Stream<SessionState> changes, SessionState current) {
    unawaited(_subscription?.cancel());
    _subscription = changes.listen(onSession);
    onSession(current);
  }

  /// Public for tests.
  void onSession(SessionState state) {
    switch (state) {
      case SessionSignedIn(:final session):
        if (session.userId == _userId) return;
        _userId = session.userId;
        _run();
      case SessionSignedOut() || SessionUnknown():
        _userId = null;
    }
  }

  /// Call when the app returns to the foreground.
  void onResume() {
    if (_userId != null) _run();
  }

  void _run() => unawaited(_recover().then<void>((_) {}, onError: (_) {}));

  Future<void> dispose() async => _subscription?.cancel();
}
