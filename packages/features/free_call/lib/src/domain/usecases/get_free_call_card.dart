import 'package:dashuri_core/dashuri_core.dart';

import '../entities/free_call_card.dart';
import '../repositories/free_call_repository.dart';

/// GET /v1/free-call/card
// Not final: application tests mock use cases.
class GetFreeCallCard implements UseCase<FreeCallCard, NoInput> {
  const GetFreeCallCard(this._repository);

  final FreeCallRepository _repository;

  @override
  Future<Result<FreeCallCard>> call(NoInput input) =>
      _repository.getFreeCallCard();
}
