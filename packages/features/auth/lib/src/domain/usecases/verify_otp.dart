import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/auth_repository.dart';

// Not final: application tests mock use cases.
class VerifyOtp
    implements UseCase<AuthSession, ({String e164Phone, String code})> {
  const VerifyOtp(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(({String e164Phone, String code}) input) =>
      _repository.verifyOtp(e164Phone: input.e164Phone, code: input.code);
}
