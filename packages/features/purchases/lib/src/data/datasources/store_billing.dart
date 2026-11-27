import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/purchase_update.dart';

/// Port for the app store's billing library. Android: Google Play Billing.
/// iOS (future): StoreKit, only after Apple's rules are reviewed (R3-2).
abstract interface class StoreBilling {
  /// True when running on Android with Play Billing reachable.
  Future<bool> isAvailable();

  /// Localized price per product id.
  Future<Result<Map<String, String>>> queryPrices(Set<String> productIds);

  Future<Result<void>> launchPurchase(String productId);

  Stream<PurchaseUpdate> updates();

  /// Asks the store to re-deliver purchases that were paid but never
  /// finished (still owned). They arrive on [updates] like new purchases.
  /// Best effort: never throws.
  Future<void> recoverUnfinished();

  /// Acknowledge/complete with the store AFTER the server has answered
  /// `credited` or `rejected`, so a crash in between never loses a paid purchase.
  Future<Result<void>> complete(String purchaseToken);
}
