import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/call_repository.dart';

/// GET /v1/wallet → available Diamonds.
// Not final: application tests mock use cases.
class GetAvailableDiamonds implements UseCase<int, NoInput> {
  const GetAvailableDiamonds(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<int>> call(NoInput input) => _repository.availableDiamonds();
}
