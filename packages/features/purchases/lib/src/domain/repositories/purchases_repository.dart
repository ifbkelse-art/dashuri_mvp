import 'package:dashuri_core/dashuri_core.dart';

import '../entities/diamond_package.dart';
import '../entities/purchase_update.dart';
import '../entities/purchase_verification.dart';

abstract interface class PurchasesRepository {
  /// Server catalogue merged with Play product details.
  Future<Result<List<DiamondPackage>>> loadPackages();

  /// Opens the Play purchase sheet. The outcome arrives on [purchaseUpdates].
  Future<Result<void>> startPurchase(String productId);

  /// Every purchase event from Play, including ones from previous sessions
  /// that were never verified (the app must verify those on start-up).
  Stream<PurchaseUpdate> purchaseUpdates();

  /// Sends the token to the server, which verifies it with Google and credits
  /// the ledger. On `credited`, the repository completes the purchase with Play.
  Future<Result<PurchaseVerification>> verify(
    PurchaseNeedsVerification purchase,
    IdempotencyKey key,
  );
}
