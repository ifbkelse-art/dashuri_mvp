import 'dart:io';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:test/test.dart';

final class _Tokens implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => 'secret-token';
}

void main() {
  late HttpServer server;
  late List<(String, String?, String?, List<int>)> seen;
  var status = 200;

  setUp(() async {
    seen = [];
    status = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final bytes = <int>[];
      await for (final chunk in req) {
        bytes.addAll(chunk);
      }
      seen.add((
        req.method,
        req.headers.value('authorization'),
        req.headers.contentType?.mimeType,
        bytes,
      ));
      req.response.statusCode = status;
      await req.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  ApiClient client() =>
      ApiClient(baseUrl: Uri.parse('http://unused.invalid'), tokens: _Tokens());

  Uri url() => Uri.parse('http://127.0.0.1:${server.port}/upload/p1?sig=x');

  test('PUTs the raw bytes without the bearer token', () async {
    final r = await client().uploadToSignedUrl(url(), [
      1,
      2,
      3,
      250,
    ], contentType: 'image/jpeg');
    expect(r.isSuccess, isTrue);
    final (method, auth, type, body) = seen.single;
    expect(method, 'PUT');
    expect(auth, isNull);
    expect(type, 'image/jpeg');
    expect(body, [1, 2, 3, 250]);
  });

  test('a rejected upload is a failure, never a throw', () async {
    status = 403;
    final r = await client().uploadToSignedUrl(url(), [
      1,
    ], contentType: 'image/png');
    expect((r as Err).failure.code, 'upload_rejected');
  });

  test('an unreachable URL is a NetworkFailure', () async {
    final dead = url();
    await server.close(force: true);
    final r = await client().uploadToSignedUrl(dead, [
      1,
    ], contentType: 'image/png');
    expect((r as Err).failure, isA<NetworkFailure>());
  });
}
