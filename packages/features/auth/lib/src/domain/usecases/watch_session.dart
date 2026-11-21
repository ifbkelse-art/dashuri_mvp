import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/auth_repository.dart';

// Not final: application tests mock use cases.
class WatchSession implements StreamUseCase<AuthSession?, NoInput> {
  const WatchSession(this._repository);

  final AuthRepository _repository;

  @override
  Stream<AuthSession?> call(NoInput input) => _repository.watchSession();
}
