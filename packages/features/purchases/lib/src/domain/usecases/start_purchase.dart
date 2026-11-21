import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/purchases_repository.dart';

// Not final: application tests mock use cases.
class StartPurchase implements UseCase<void, String> {
  const StartPurchase(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<void>> call(String productId) =>
      _repository.startPurchase(productId);
}
