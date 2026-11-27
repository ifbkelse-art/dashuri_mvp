import 'dart:io';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:test/test.dart';

final class _ThrowingTokens implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async =>
      throw const SocketException('refresh failed: offline');
}

void main() {
  // Regression (2026-11-27): when the session had expired and the refresh
  // failed (offline / revoked), the exception escaped ApiClient instead of
  // becoming a Failure, so callers awaiting a Result got an unhandled error.
  test(
    'a failed session refresh becomes a NetworkFailure, not an exception',
    () async {
      var hit = false;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        hit = true;
        await req.response.close();
      });
      addTearDown(() => server.close(force: true));
      final client = ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        tokens: _ThrowingTokens(),
      );
      final r = await client.get<Object?>('/v1/me', decode: (j) => j);
      expect(r, isA<Err<Object?>>());
      expect((r as Err<Object?>).failure, isA<NetworkFailure>());
      expect(hit, isFalse, reason: 'no unauthenticated request is sent');
    },
  );
}
