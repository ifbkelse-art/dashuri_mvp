import 'package:dashuri_core/dashuri_core.dart';

import '../entities/purchase_update.dart';
import '../entities/purchase_verification.dart';
import '../repositories/purchases_repository.dart';

/// POST /v1/purchases/google-play. The server also deduplicates on the
/// purchase token, so a replayed token can never credit twice.
// Not final: application tests mock use cases.
class VerifyPurchase
    implements
        UseCase<
          PurchaseVerification,
          ({PurchaseNeedsVerification purchase, IdempotencyKey key})
        > {
  const VerifyPurchase(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<PurchaseVerification>> call(
    ({PurchaseNeedsVerification purchase, IdempotencyKey key}) input,
  ) => _repository.verify(input.purchase, input.key);
}
