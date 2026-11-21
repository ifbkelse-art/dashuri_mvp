import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/auth_repository.dart';

// Not final: application tests mock use cases.
class SignOut implements UseCase<void, NoInput> {
  const SignOut(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(NoInput input) => _repository.signOut();
}
