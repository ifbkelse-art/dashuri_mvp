import 'package:dashuri_core/dashuri_core.dart';

import '../entities/payment_rail.dart';
import '../repositories/purchases_repository.dart';

/// Rails supported by this device and app build.
// Not final: application tests mock use cases.
class GetClientRails implements UseCase<Set<PaymentRail>, NoInput> {
  const GetClientRails(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<Set<PaymentRail>>> call(NoInput input) async =>
      Success(await _repository.clientRails());
}
