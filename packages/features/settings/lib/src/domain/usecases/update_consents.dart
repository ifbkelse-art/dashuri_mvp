import 'package:dashuri_core/dashuri_core.dart';

import '../entities/consent_state.dart';
import '../repositories/settings_repository.dart';

/// PUT /v1/me/consents
// Not final: application tests mock use cases.
class UpdateConsents
    implements UseCase<ConsentState, ({bool analytics, bool marketing})> {
  const UpdateConsents(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<ConsentState>> call(({bool analytics, bool marketing}) input) =>
      _repository.updateConsents(
        analytics: input.analytics,
        marketing: input.marketing,
      );
}
