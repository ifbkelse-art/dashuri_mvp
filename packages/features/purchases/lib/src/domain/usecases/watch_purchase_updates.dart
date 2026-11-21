import 'package:dashuri_core/dashuri_core.dart';

import '../entities/purchase_update.dart';
import '../repositories/purchases_repository.dart';

// Not final: application tests mock use cases.
class WatchPurchaseUpdates implements StreamUseCase<PurchaseUpdate, NoInput> {
  const WatchPurchaseUpdates(this._repository);

  final PurchasesRepository _repository;

  @override
  Stream<PurchaseUpdate> call(NoInput input) => _repository.purchaseUpdates();
}
