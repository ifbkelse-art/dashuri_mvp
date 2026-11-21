import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Supabase Auth (phone OTP) behind the [SessionGateway] contract.
final class SupabaseSessionGateway
    implements SessionGateway, AccessTokenProvider {
  SupabaseSessionGateway(this._client);

  final sb.SupabaseClient _client;

  @override
  Stream<AuthSession?> watchSession() =>
      _client.auth.onAuthStateChange.map((event) => _map(event.session));

  @override
  AuthSession? get currentSession => _map(_client.auth.currentSession);

  @override
  Future<String?> accessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      final refreshed = await _client.auth.refreshSession();
      return refreshed.session?.accessToken;
    }
    return session.accessToken;
  }

  @override
  Future<Result<void>> requestPhoneOtp(String e164Phone) =>
      _guard(() => _client.auth.signInWithOtp(phone: e164Phone));

  @override
  Future<Result<AuthSession>> verifyPhoneOtp({
    required String e164Phone,
    required String code,
  }) async {
    final result = await _guard(
      () => _client.auth.verifyOTP(
        phone: e164Phone,
        token: code,
        type: sb.OtpType.sms,
      ),
    );
    return switch (result) {
      Success(:final value) => switch (_map(value.session)) {
        final AuthSession s => Success(s),
        null => const Err(
          UnauthenticatedFailure(message: 'No session after OTP verification'),
        ),
      },
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> signOut() => _guard(() => _client.auth.signOut());

  AuthSession? _map(sb.Session? s) => s == null
      ? null
      : AuthSession(
          userId: s.user.id,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            (s.expiresAt ?? 0) * 1000,
            isUtc: true,
          ),
        );

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Success(await run());
    } on sb.AuthException catch (e) {
      return Err(
        e.statusCode == '429'
            ? RateLimitedFailure(message: e.message)
            : ValidationFailure(message: e.message),
      );
    } on Exception catch (e) {
      return Err(NetworkFailure(message: '$e'));
    }
  }
}
