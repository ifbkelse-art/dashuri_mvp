import 'package:dashuri_core/dashuri_core.dart';

import '../entities/cashfree_checkout_outcome.dart';
import '../entities/cashfree_order.dart';
import '../repositories/purchases_repository.dart';

/// POST /v1/purchases/cashfree/orders. Pass the SAME key for every retry of
/// one "Pay" intent.
// Not final: application tests mock use cases.
class CreateCashfreeOrder
    implements
        UseCase<CashfreeOrder, ({String productId, IdempotencyKey key})> {
  const CreateCashfreeOrder(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<CashfreeOrder>> call(
    ({String productId, IdempotencyKey key}) input,
  ) => _repository.createCashfreeOrder(input.productId, input.key);
}

/// GET /v1/purchases/cashfree/orders/{orderId}: the server's verdict.
// Not final: application tests mock use cases.
class GetCashfreeOrder implements UseCase<CashfreeOrder, String> {
  const GetCashfreeOrder(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<CashfreeOrder>> call(String orderId) =>
      _repository.getCashfreeOrder(orderId);
}

/// Opens the Cashfree checkout UI and reports what it said.
// Not final: application tests mock use cases.
class OpenCashfreeCheckout
    implements UseCase<CashfreeCheckoutOutcome, CashfreeOrder> {
  const OpenCashfreeCheckout(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<CashfreeCheckoutOutcome>> call(CashfreeOrder order) async =>
      Success(await _repository.openCashfreeCheckout(order));
}
