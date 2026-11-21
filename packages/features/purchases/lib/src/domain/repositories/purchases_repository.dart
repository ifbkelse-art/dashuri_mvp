import 'package:dashuri_core/dashuri_core.dart';

import '../entities/cashfree_checkout_outcome.dart';
import '../entities/cashfree_order.dart';
import '../entities/package_catalogue.dart';
import '../entities/payment_rail.dart';
import '../entities/purchase_update.dart';
import '../entities/purchase_verification.dart';

abstract interface class PurchasesRepository {
  /// Server catalogue (prices, rails) merged with Play product details.
  Future<Result<PackageCatalogue>> loadPackages();

  /// Rails this app build and device support: Google Play when running on
  /// Android with Play Billing available; Cashfree when the app flag is on.
  Future<Set<PaymentRail>> clientRails();

  /// Opens the Play purchase sheet. The outcome arrives on [purchaseUpdates].
  Future<Result<void>> startPurchase(String productId);

  /// Every purchase event from Play, including ones from previous sessions
  /// that were never verified.
  Stream<PurchaseUpdate> purchaseUpdates();

  /// Sends the token to the server, which verifies it with Google and credits
  /// the ledger. On `credited` or `rejected` the repository completes the
  /// purchase with Play; on `pending` it does not.
  Future<Result<PurchaseVerification>> verify(
    PurchaseNeedsVerification purchase,
    IdempotencyKey key,
  );

  /// POST /v1/purchases/cashfree/orders
  Future<Result<CashfreeOrder>> createCashfreeOrder(
    String productId,
    IdempotencyKey key,
  );

  /// GET /v1/purchases/cashfree/orders/{orderId}; the server re-verifies with
  /// Cashfree and credits once.
  Future<Result<CashfreeOrder>> getCashfreeOrder(String orderId);

  /// Opens the Cashfree checkout UI.
  Future<CashfreeCheckoutOutcome> openCashfreeCheckout(CashfreeOrder order);
}
