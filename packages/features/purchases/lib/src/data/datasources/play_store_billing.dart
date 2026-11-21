import 'package:dashuri_core/dashuri_core.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../domain/entities/purchase_update.dart';
import 'store_billing.dart';

/// Google Play Billing adapter (in_app_purchase). NOT IMPLEMENTED YET.
///
/// TODO(billing): implement with in_app_purchase:
///  1. queryPrices → `_iap.queryProductDetails(ids)`; map to localized prices.
///  2. launchPurchase → `_iap.buyConsumable(..., autoConsume: false)`.
///  3. updates → map `_iap.purchaseStream` statuses (pending, purchased,
///     restored, canceled, error) to [PurchaseUpdate]s, passing the
///     server-verification data (purchase token) on `purchased`.
///  4. complete → only after server status `credited`: `_iap.completePurchase`
///     and consume via the Android platform addition, per current Play Billing
///     requirements (verify the exact acknowledge/consume sequence before release).
/// Never credit Diamonds on the device.
final class PlayStoreBilling implements StoreBilling {
  PlayStoreBilling([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  // ignore: unused_field
  final InAppPurchase _iap;

  static const _notImplemented = PlatformFailure(
    code: 'billing_not_implemented',
  );

  @override
  Future<Result<Map<String, String>>> queryPrices(
    Set<String> productIds,
  ) async => const Err(_notImplemented);

  @override
  Future<Result<void>> launchPurchase(String productId) async =>
      const Err(_notImplemented);

  @override
  Stream<PurchaseUpdate> updates() => const Stream.empty();

  @override
  Future<Result<void>> complete(String purchaseToken) async =>
      const Err(_notImplemented);
}
