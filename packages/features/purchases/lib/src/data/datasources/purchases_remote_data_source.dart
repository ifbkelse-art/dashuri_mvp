import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/cashfree_order.dart';
import '../../domain/entities/package_catalogue.dart';
import '../../domain/entities/purchase_update.dart';
import '../../domain/entities/purchase_verification.dart';
import '../models/purchases_json.dart';

// Not final: repository tests mock it.
class PurchasesRemoteDataSource {
  const PurchasesRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<PackageCatalogue>> catalogue() => _api.get(
    '/v1/purchases/packages',
    decode: objectDecoder(packageCatalogueFromJson),
  );

  /// Available Diamonds for the "Current balance" row (W02).
  Future<Result<int>> availableDiamonds() => _api.get(
    '/v1/wallet',
    decode: objectDecoder((j) => (j['available_diamonds']! as num).toInt()),
  );

  Future<Result<PurchaseVerification>> verifyGooglePlay(
    PurchaseNeedsVerification p,
    IdempotencyKey key,
  ) => _api.post(
    '/v1/purchases/google-play',
    decode: objectDecoder(purchaseVerificationFromJson),
    body: {
      'product_id': p.productId,
      'purchase_token': p.purchaseToken,
      if (p.orderId != null) 'order_id': p.orderId,
    },
    idempotencyKey: key,
  );

  Future<Result<CashfreeOrder>> createCashfreeOrder(
    String productId,
    IdempotencyKey key,
  ) => _api.post(
    '/v1/purchases/cashfree/orders',
    decode: objectDecoder(cashfreeOrderFromJson),
    body: {'product_id': productId},
    idempotencyKey: key,
  );

  Future<Result<CashfreeOrder>> getCashfreeOrder(String orderId) => _api.get(
    '/v1/purchases/cashfree/orders/${Uri.encodeComponent(orderId)}',
    decode: objectDecoder(cashfreeOrderFromJson),
  );
}
