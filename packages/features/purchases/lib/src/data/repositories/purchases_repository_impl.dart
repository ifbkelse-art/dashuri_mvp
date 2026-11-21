import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/cashfree_checkout_outcome.dart';
import '../../domain/entities/cashfree_order.dart';
import '../../domain/entities/package_catalogue.dart';
import '../../domain/entities/payment_rail.dart';
import '../../domain/entities/purchase_update.dart';
import '../../domain/entities/purchase_verification.dart';
import '../../domain/ports/cashfree_checkout.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../datasources/purchases_remote_data_source.dart';
import '../datasources/store_billing.dart';

final class PurchasesRepositoryImpl implements PurchasesRepository {
  const PurchasesRepositoryImpl(
    this._remote,
    this._store,
    this._cashfree, {
    required this.cashfreeEnabled,
  });

  final PurchasesRemoteDataSource _remote;
  final StoreBilling _store;
  final CashfreeCheckout _cashfree;

  /// App flag `DASHURI_CASHFREE_ENABLED` (founder decision F1).
  final bool cashfreeEnabled;

  @override
  Future<Result<PackageCatalogue>> loadPackages() async {
    final (catalogue, balance) = await (
      _remote.catalogue(),
      _remote.availableDiamonds(),
    ).wait;
    if (catalogue case Err(:final failure)) return Err(failure);
    final c = (catalogue as Success<PackageCatalogue>).value;
    var packages = c.packages;
    if (c.rails.contains(PaymentRail.googlePlay) &&
        await _store.isAvailable()) {
      final prices = await _store.queryPrices(
        packages.map((p) => p.productId).toSet(),
      );
      final map = prices.fold(
        onSuccess: (p) => p,
        onFailure: (_) => const <String, String>{},
      );
      packages = [for (final p in packages) p.withStorePrice(map[p.productId])];
    }
    return Success(
      PackageCatalogue(
        packages: packages,
        rails: c.rails,
        approxPaisePerDiamondMilli: c.approxPaisePerDiamondMilli,
        currentBalance: balance.fold(
          onSuccess: (b) => b,
          onFailure: (_) => null,
        ),
      ),
    );
  }

  @override
  Future<Set<PaymentRail>> clientRails() async => {
    if (await _store.isAvailable()) PaymentRail.googlePlay,
    if (cashfreeEnabled) PaymentRail.cashfree,
  };

  @override
  Future<Result<void>> startPurchase(String productId) =>
      _store.launchPurchase(productId);

  @override
  Stream<PurchaseUpdate> purchaseUpdates() => _store.updates();

  @override
  Future<Result<PurchaseVerification>> verify(
    PurchaseNeedsVerification purchase,
    IdempotencyKey key,
  ) async {
    final result = await _remote.verifyGooglePlay(purchase, key);
    if (result case Success(
      :final value,
    ) when value.status == 'credited' || value.status == 'rejected') {
      // Only now tell the store the purchase is finished.
      await _store.complete(purchase.purchaseToken);
    }
    return result;
  }

  @override
  Future<Result<CashfreeOrder>> createCashfreeOrder(
    String productId,
    IdempotencyKey key,
  ) => _remote.createCashfreeOrder(productId, key);

  @override
  Future<Result<CashfreeOrder>> getCashfreeOrder(String orderId) =>
      _remote.getCashfreeOrder(orderId);

  @override
  Future<CashfreeCheckoutOutcome> openCashfreeCheckout(CashfreeOrder order) =>
      _cashfree.open(order);
}
