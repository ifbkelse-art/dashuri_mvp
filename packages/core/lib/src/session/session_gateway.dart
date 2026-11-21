import '../result/result.dart';
import 'auth_session.dart';

/// Contract for the identity provider (Supabase Auth today). Implemented in
/// `dashuri_supabase`; features depend only on this interface.
abstract interface class SessionGateway {
  /// Emits the current session and every change (sign-in, refresh, sign-out).
  Stream<AuthSession?> watchSession();

  AuthSession? get currentSession;

  /// Short-lived access token for the Go API, refreshed if needed.
  Future<String?> accessToken();

  Future<Result<void>> requestPhoneOtp(String e164Phone);

  Future<Result<AuthSession>> verifyPhoneOtp({
    required String e164Phone,
    required String code,
  });

  Future<Result<void>> signOut();
}
