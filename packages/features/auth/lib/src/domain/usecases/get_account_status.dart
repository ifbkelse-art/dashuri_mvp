import 'package:dashuri_core/dashuri_core.dart';

import '../entities/account_status.dart';
import '../repositories/auth_repository.dart';

// Not final: application tests mock use cases.
class GetAccountStatus implements UseCase<AccountStatus, NoInput> {
  const GetAccountStatus(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AccountStatus>> call(NoInput input) =>
      _repository.getAccountStatus();
}
