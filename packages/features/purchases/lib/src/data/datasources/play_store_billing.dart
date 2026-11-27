import 'package:dashuri_core/dashuri_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../domain/entities/purchase_update.dart';
import 'sha256.dart';
import 'store_billing.dart';

/// Google Play Billing adapter (`in_app_purchase`).
///
/// - Products are queried by the server catalogue's `product_id`.
/// - Purchases use `buyConsumable(autoConsume: false)` with
///   `applicationUserName = sha256(userId)` (Play's obfuscatedAccountId), so
///   nothing is consumed before the server has verified the token.
/// - [complete] calls `completePurchase` only after the server said
///   `credited` or `rejected`. The server consumes the token with the Play
///   Developer API when it credits, so the pack can be bought again.
/// Never credits Diamonds on the device.
final class PlayStoreBilling implements StoreBilling {
  PlayStoreBilling({
    required SessionGateway session,
    InAppPurchase? iap,
    bool Function()? isAndroid,
  }) : _session = session,
       _iapOverride = iap,
       _isAndroid =
           isAndroid ??
           (() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final SessionGateway _session;
  final InAppPurchase? _iapOverride;
  final bool Function() _isAndroid;
  final Map<String, ProductDetails> _products = {};

  /// Purchases awaiting the server's answer, by purchase token.
  final Map<String, PurchaseDetails> _awaitingCompletion = {};

  // Resolved lazily: touching the plugin off Android is not allowed.
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  static const _unavailable = PlatformFailure(
    code: 'billing_unavailable',
    message: 'Google Play Billing is not available on this device.',
  );

  @override
  Future<bool> isAvailable() async {
    if (!_isAndroid()) return false;
    try {
      return await _iap.isAvailable();
    } on Object {
      return false;
    }
  }

  @override
  Future<Result<Map<String, String>>> queryPrices(
    Set<String> productIds,
  ) async {
    if (!await isAvailable()) return const Err(_unavailable);
    try {
      final response = await _iap.queryProductDetails(productIds);
      if (response.error case final IAPError e) {
        return Err(PlatformFailure(code: e.code, message: e.message));
      }
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
      return Success({for (final p in response.productDetails) p.id: p.price});
    } on PlatformException catch (e) {
      return Err(PlatformFailure(code: e.code, message: e.message));
    }
  }

  @override
  Future<Result<void>> launchPurchase(String productId) async {
    final userId = _session.currentSession?.userId;
    if (userId == null) return const Err(UnauthenticatedFailure());
    if (!_products.containsKey(productId)) {
      final prices = await queryPrices({productId});
      if (prices case Err(:final failure)) return Err(failure);
      if (!_products.containsKey(productId)) {
        return const Err(PlatformFailure(code: 'product_not_found'));
      }
    }
    try {
      final launched = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: _products[productId]!,
          applicationUserName: sha256Hex(userId),
        ),
        autoConsume: false,
      );
      return launched
          ? const Success(null)
          : const Err(PlatformFailure(code: 'billing_launch_failed'));
    } on InAppPurchaseException catch (e) {
      return Err(PlatformFailure(code: e.code, message: e.message));
    } on PlatformException catch (e) {
      return Err(PlatformFailure(code: e.code, message: e.message));
    }
  }

  @override
  Stream<PurchaseUpdate> updates() {
    if (!_isAndroid()) return const Stream.empty();
    return _iap.purchaseStream.expand((list) => list.map(_toUpdate));
  }

  /// Play only re-delivers a purchase that was paid but never finished (the
  /// app died before the server verified it, or the server's consume
  /// failed) when asked. On Android `restorePurchases` returns the purchases
  /// still owned (not consumed), each as `restored`, on [updates]. They go
  /// through the normal server verification, which credits a token once and
  /// consumes it, so a recovered purchase is never credited twice.
  @override
  Future<void> recoverUnfinished() async {
    if (!_isAndroid()) return;
    final userId = _session.currentSession?.userId;
    if (userId == null) return;
    try {
      if (!await _iap.isAvailable()) return;
      await _iap.restorePurchases(applicationUserName: sha256Hex(userId));
    } on Object {
      // Best effort; the next start or resume retries.
    }
  }

  PurchaseUpdate _toUpdate(PurchaseDetails d) {
    switch (d.status) {
      case PurchaseStatus.pending:
        return PurchasePending(d.productID);
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final token = d.verificationData.serverVerificationData;
        _awaitingCompletion[token] = d;
        return PurchaseNeedsVerification(
          d.productID,
          purchaseToken: token,
          orderId: d.purchaseID,
        );
      case PurchaseStatus.canceled:
        return PurchaseCancelled(d.productID);
      case PurchaseStatus.error:
        return PurchaseStoreError(
          d.productID,
          d.error?.code ?? 'billing_error',
        );
    }
  }

  @override
  Future<Result<void>> complete(String purchaseToken) async {
    final details = _awaitingCompletion.remove(purchaseToken);
    if (details == null || !details.pendingCompletePurchase) {
      return const Success(null);
    }
    try {
      await _iap.completePurchase(details);
      return const Success(null);
    } on Object catch (e) {
      // Keep it so a later retry can complete it.
      _awaitingCompletion[purchaseToken] = details;
      return Err(PlatformFailure(code: 'complete_failed', message: '$e'));
    }
  }
}
