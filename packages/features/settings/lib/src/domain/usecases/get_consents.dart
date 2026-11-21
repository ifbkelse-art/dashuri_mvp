import 'package:dashuri_core/dashuri_core.dart';

import '../entities/consent_state.dart';
import '../repositories/settings_repository.dart';

/// GET /v1/me/consents
// Not final: application tests mock use cases.
class GetConsents implements UseCase<ConsentState, NoInput> {
  const GetConsents(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<ConsentState>> call(NoInput input) => _repository.getConsents();
}
