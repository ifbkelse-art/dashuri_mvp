import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/purchase_update.dart';

/// Port for the app store's billing library. Android: Google Play Billing.
/// iOS (future): StoreKit, only after Apple's rules are reviewed (R3-2).
abstract interface class StoreBilling {
  /// Localized price per product id.
  Future<Result<Map<String, String>>> queryPrices(Set<String> productIds);

  Future<Result<void>> launchPurchase(String productId);

  Stream<PurchaseUpdate> updates();

  /// Acknowledge/consume with the store AFTER the server has credited the
  /// ledger, so a crash in between never loses a paid purchase.
  Future<Result<void>> complete(String purchaseToken);
}
