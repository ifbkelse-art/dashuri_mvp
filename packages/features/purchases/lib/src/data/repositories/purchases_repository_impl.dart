import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/diamond_package.dart';
import '../../domain/entities/purchase_update.dart';
import '../../domain/entities/purchase_verification.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../datasources/purchases_remote_data_source.dart';
import '../datasources/store_billing.dart';

final class PurchasesRepositoryImpl implements PurchasesRepository {
  const PurchasesRepositoryImpl(this._remote, this._store);

  final PurchasesRemoteDataSource _remote;
  final StoreBilling _store;

  @override
  Future<Result<List<DiamondPackage>>> loadPackages() async {
    final catalogue = await _remote.catalogue();
    if (catalogue case Err(:final failure)) return Err(failure);
    final items =
        (catalogue as Success<List<({String productId, int diamonds})>>).value;
    final prices = await _store.queryPrices(
      items.map((i) => i.productId).toSet(),
    );
    final priceMap = prices.fold(
      onSuccess: (p) => p,
      onFailure: (_) => const <String, String>{},
    );
    return Success([
      for (final i in items)
        DiamondPackage(
          productId: i.productId,
          diamonds: i.diamonds,
          storePrice: priceMap[i.productId],
        ),
    ]);
  }

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
    if (result case Success(:final value) when value.status == 'credited') {
      // Only now tell the store the purchase is fulfilled.
      await _store.complete(purchase.purchaseToken);
    }
    return result;
  }
}
