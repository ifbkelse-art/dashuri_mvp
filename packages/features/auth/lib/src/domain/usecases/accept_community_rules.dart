import 'package:dashuri_core/dashuri_core.dart';

import '../entities/account_status.dart';
import '../repositories/auth_repository.dart';

/// POST /v1/me/rules-acceptance with the current rules version.
// Not final: application tests mock use cases.
class AcceptCommunityRules implements UseCase<AccountStatus, NoInput> {
  const AcceptCommunityRules(this._repository);

  /// Version of the community rules shown in A13 (MVP contract 2.1).
  static const currentVersion = '2026-11';

  final AuthRepository _repository;

  @override
  Future<Result<AccountStatus>> call(NoInput input) =>
      _repository.acceptCommunityRules(currentVersion);
}
