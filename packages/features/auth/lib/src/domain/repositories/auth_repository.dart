import 'package:dashuri_core/dashuri_core.dart';

import '../entities/account_status.dart';

abstract interface class AuthRepository {
  Stream<AuthSession?> watchSession();

  Future<Result<void>> requestOtp(String e164Phone);

  Future<Result<AuthSession>> verifyOtp({
    required String e164Phone,
    required String code,
  });

  Future<Result<AccountStatus>> getAccountStatus();

  /// POST /v1/me/rules-acceptance
  Future<Result<AccountStatus>> acceptCommunityRules(String version);

  Future<Result<void>> signOut();
}
