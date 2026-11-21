import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

/// Used only when `config/<env>.json` is missing, so the app can start while
/// pages are being built. Every call fails with `backend_not_configured`;
/// nothing is faked. Never used in staging or production builds.
final class UnconfiguredBackend
    implements SessionGateway, AccessTokenProvider, RealtimeGateway {
  const UnconfiguredBackend();

  static const _failure = PlatformFailure(code: 'backend_not_configured');

  @override
  Stream<AuthSession?> watchSession() => Stream.value(null);

  @override
  AuthSession? get currentSession => null;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<Result<void>> requestPhoneOtp(String e164Phone) async =>
      const Err(_failure);

  @override
  Future<Result<AuthSession>> verifyPhoneOtp({
    required String e164Phone,
    required String code,
  }) async => const Err(_failure);

  @override
  Future<Result<void>> signOut() async => const Err(_failure);

  @override
  Stream<RealtimeEvent> subscribe(String channel) => const Stream.empty();
}
