import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';

import '../domain/entities/purchase_update.dart';
import '../domain/repositories/purchases_repository.dart';

/// Finishes Google Play purchases that were paid but never verified.
///
/// The app runs it once per signed-in user at start-up and again on every
/// return to the foreground (see the app's composition root), so a customer
/// who paid while the app was killed gets the Diamonds without opening the
/// purchase screen. Each re-delivered token goes through the normal server
/// verification: the server credits a token once and consumes it, and the
/// repository shares one in-flight request per token with any open purchase
/// screen. Diamonds are never credited on the device.
// Not final: app tests mock it.
class PurchaseRecovery {
  PurchaseRecovery(this._repository, {this.grace = const Duration(seconds: 3)});

  final PurchasesRepository _repository;

  /// How long to keep listening after asking the store, for re-delivered
  /// purchases to arrive.
  final Duration grace;

  Future<int>? _running;

  /// Runs one recovery pass; a call while one is running joins it. Returns
  /// the number of purchases sent to the server for verification.
  Future<int> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<int> _run() async {
    final verifications = <Future<void>>[];
    final sub = _repository.purchaseUpdates().listen((u) {
      if (u is PurchaseNeedsVerification) {
        verifications.add(_repository.verify(u, IdempotencyKey.generate()));
      }
    });
    try {
      await _repository.recoverUnfinished();
      await Future<void>.delayed(grace);
    } finally {
      await sub.cancel();
    }
    await Future.wait(verifications);
    return verifications.length;
  }
}
