import 'dart:convert';
import 'dart:io';

import 'package:dashuri_network/dashuri_network.dart';

final class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final Object? body;
}

final class _NoToken implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => 'test-token';
}

/// A real local HTTP server for data-source tests: the [ApiClient] talks to
/// it over the wire, so paths, bodies and headers are checked exactly.
final class FakeApi {
  FakeApi._(this._server);

  final HttpServer _server;
  final List<RecordedRequest> requests = [];
  int status = 200;
  Object? response;

  static Future<FakeApi> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = FakeApi._(server);
    server.listen(api._handle);
    return api;
  }

  ApiClient get client => ApiClient(
    baseUrl: Uri.parse('http://127.0.0.1:${_server.port}'),
    tokens: _NoToken(),
  );

  RecordedRequest get last => requests.last;

  int get port => _server.port;

  Future<void> _handle(HttpRequest req) async {
    final text = await utf8.decoder.bind(req).join();
    requests.add(
      RecordedRequest(
        req.method,
        req.uri,
        req.headers,
        text.isEmpty ? null : _tryJson(text),
      ),
    );
    req.response.statusCode = status;
    if (response != null) {
      req.response.headers.contentType = status >= 400
          ? ContentType('application', 'problem+json')
          : ContentType.json;
      req.response.write(jsonEncode(response));
    }
    await req.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

Object? _tryJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}
