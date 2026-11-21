import 'package:dashuri_core/dashuri_core.dart';

import '../entities/diamond_package.dart';
import '../repositories/purchases_repository.dart';

// Not final: application tests mock use cases.
class LoadDiamondPackages implements UseCase<List<DiamondPackage>, NoInput> {
  const LoadDiamondPackages(this._repository);

  final PurchasesRepository _repository;

  @override
  Future<Result<List<DiamondPackage>>> call(NoInput input) =>
      _repository.loadPackages();
}
