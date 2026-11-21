import 'package:dashuri_core/dashuri_core.dart';

import '../entities/messaging_privacy.dart';
import '../repositories/settings_repository.dart';

// Not final: application tests mock use cases.
class GetMessagingPrivacy implements UseCase<WhoCanMessage, NoInput> {
  const GetMessagingPrivacy(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<WhoCanMessage>> call(NoInput input) =>
      _repository.getMessagingPrivacy();
}

// Not final: application tests mock use cases.
class SetMessagingPrivacy implements UseCase<WhoCanMessage, WhoCanMessage> {
  const SetMessagingPrivacy(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<WhoCanMessage>> call(WhoCanMessage input) =>
      _repository.setMessagingPrivacy(input);
}

// Not final: application tests mock use cases.
class GetDiamondBalance implements UseCase<int, NoInput> {
  const GetDiamondBalance(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<int>> call(NoInput input) => _repository.getAvailableDiamonds();
}

/// Max grievance length (sent as report `details`, API max 1,000).
const grievanceMaxLength = 1000;

// Not final: application tests mock use cases.
class SubmitGrievance
    implements
        UseCase<String, ({String details, IdempotencyKey idempotencyKey})> {
  const SubmitGrievance(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<String>> call(
    ({String details, IdempotencyKey idempotencyKey}) input,
  ) => _repository.submitGrievance(
    details: input.details,
    idempotencyKey: input.idempotencyKey,
  );
}

// Not final: application tests mock use cases.
class SignOutUser implements UseCase<void, NoInput> {
  const SignOutUser(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<void>> call(NoInput input) => _repository.signOut();
}
