import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/purchase_update.dart';
import '../../domain/entities/purchase_verification.dart';
import '../models/purchases_json.dart';

final class PurchasesRemoteDataSource {
  const PurchasesRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<List<({String productId, int diamonds})>>> catalogue() =>
      _api.get(
        '/v1/purchases/packages',
        decode: (json) => ((json! as JsonMap)['items']! as List<Object?>)
            .cast<JsonMap>()
            .map(catalogueItemFromJson)
            .toList(),
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
}
