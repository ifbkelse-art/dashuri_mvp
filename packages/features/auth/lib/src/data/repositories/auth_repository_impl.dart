import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/account_status.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/account_remote_data_source.dart';

/// Identity comes from the [SessionGateway] (Supabase Auth); account status
/// comes from the Go API.
final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._session, this._account);

  final SessionGateway _session;
  final AccountRemoteDataSource _account;

  @override
  Stream<AuthSession?> watchSession() => _session.watchSession();

  @override
  Future<Result<void>> requestOtp(String e164Phone) =>
      _session.requestPhoneOtp(e164Phone);

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String e164Phone,
    required String code,
  }) => _session.verifyPhoneOtp(e164Phone: e164Phone, code: code);

  @override
  Future<Result<AccountStatus>> getAccountStatus() =>
      _account.getAccountStatus();

  @override
  Future<Result<AccountStatus>> acceptCommunityRules(String version) =>
      _account.acceptCommunityRules(version);

  @override
  Future<Result<void>> signOut() => _session.signOut();
}
