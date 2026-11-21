import 'package:dashuri_core/dashuri_core.dart';

import '../entities/package_catalogue.dart';
import '../repositories/purchases_repository.dart';

/// GET /v1/purchases/packages (+ GET /v1/wallet for the current balance).
// Not final: application tests mock use cases.
class LoadDiamondPackages implements UseCase<PackageCatalogue, NoInput> {
  const LoadDiamondPackages(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<PackageCatalogue>> call(NoInput input) =>
      _repository.loadPackages();
}
