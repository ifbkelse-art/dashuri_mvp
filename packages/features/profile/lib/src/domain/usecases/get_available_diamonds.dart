import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/profile_repository.dart';

/// GET /v1/wallet → `available_diamonds` (display only).
// Not final: application tests mock use cases.
class GetAvailableDiamonds implements UseCase<int, NoInput> {
  const GetAvailableDiamonds(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<int>> call(NoInput input) => _repository.getAvailableDiamonds();
}
