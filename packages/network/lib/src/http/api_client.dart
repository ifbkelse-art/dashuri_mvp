import 'package:dashuri_core/dashuri_core.dart';
import 'package:dio/dio.dart';

import 'access_token_provider.dart';
import 'problem_mapper.dart';

typedef JsonMap = Map<String, Object?>;
typedef Decoder<T> = T Function(Object? json);

/// The single HTTP entry point for feature data sources.
///
/// - Adds the bearer token, request id and (for value-moving calls) the
///   `Idempotency-Key` header.
/// - Converts every transport or HTTP error into a [Failure]; it never throws.
final class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required AccessTokenProvider tokens,
    Dio? dio,
  }) : _tokens = tokens,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl.toString(),
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
               validateStatus: (_) => true,
             ),
           );

  final Dio _dio;
  final AccessTokenProvider _tokens;

  Future<Result<T>> get<T>(
    String path, {
    required Decoder<T> decode,
    Map<String, String>? query,
  }) => _send('GET', path, decode: decode, query: query);

  Future<Result<T>> post<T>(
    String path, {
    required Decoder<T> decode,
    JsonMap? body,
    IdempotencyKey? idempotencyKey,
  }) => _send(
    'POST',
    path,
    decode: decode,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  Future<Result<T>> put<T>(
    String path, {
    required Decoder<T> decode,
    JsonMap? body,
  }) => _send('PUT', path, decode: decode, body: body);

  Future<Result<T>> patch<T>(
    String path, {
    required Decoder<T> decode,
    JsonMap? body,
  }) => _send('PATCH', path, decode: decode, body: body);

  Future<Result<void>> delete(String path) =>
      _send<void>('DELETE', path, decode: (_) {});

  /// PUTs raw [bytes] to a pre-signed storage URL (e.g. a photo upload
  /// ticket). No bearer token is sent: the URL itself carries the grant.
  /// [onProgress] receives the sent fraction (0–1) for large uploads.
  Future<Result<void>> uploadToSignedUrl(
    Uri url,
    List<int> bytes, {
    required String contentType,
    Map<String, String> headers = const {},
    void Function(double fraction)? onProgress,
  }) async {
    try {
      final response = await _dio.requestUri<Object?>(
        url,
        data: Stream<List<int>>.value(bytes),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) =>
                  onProgress(total <= 0 ? 0 : (sent / total).clamp(0, 1)),
        options: Options(
          method: 'PUT',
          contentType: contentType,
          responseType: ResponseType.plain,
          // Signed headers from the server (R2) first; Content-Type and
          // Content-Length always describe these exact bytes.
          headers: {
            for (final e in headers.entries)
              if (e.key.toLowerCase() != 'content-type' &&
                  e.key.toLowerCase() != 'content-length')
                e.key: e.value,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return const Success(null);
      return Err(
        status >= 500
            ? ServerFailure(code: 'upload_failed', message: 'HTTP $status')
            : PlatformFailure(code: 'upload_rejected', message: 'HTTP $status'),
      );
    } on DioException catch (e) {
      return Err(NetworkFailure(message: e.message));
    }
  }

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    required Decoder<T> decode,
    Map<String, String>? query,
    JsonMap? body,
    IdempotencyKey? idempotencyKey,
  }) async {
    // Refreshing an expired session can throw (offline, or a revoked
    // refresh token). That must come back as a Result like every other
    // failure, not escape to the caller as an exception: screens waiting on
    // the Result would otherwise never leave their loading state. A revoked
    // session is also signalled by the auth state stream, which signs out.
    final String? token;
    try {
      token = await _tokens.accessToken();
    } on Object catch (e) {
      return Err(NetworkFailure(message: 'Could not refresh the session: $e'));
    }
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey.value,
            'X-Request-Id': IdempotencyKey.generate().value,
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return Success(decode(response.data));
      }
      return Err(failureFromProblem(status, response.data));
    } on DioException catch (e) {
      return Err(switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => NetworkFailure(message: e.message),
        _ => UnexpectedFailure(message: e.message),
      });
    } on FormatException catch (e) {
      return Err(
        UnexpectedFailure(message: 'Malformed response: ${e.message}'),
      );
    } on TypeError catch (e) {
      return Err(
        UnexpectedFailure(message: 'Response did not match contract: $e'),
      );
    }
  }
}

/// Decodes the API page envelope `{items: [...], next_cursor: ...}`.
Decoder<Page<T>> pageDecoder<T>(T Function(JsonMap json) item) => (json) {
  final map = json! as JsonMap;
  final items = (map['items']! as List<Object?>)
      .cast<JsonMap>()
      .map(item)
      .toList();
  return Page(items: items, nextCursor: map['next_cursor'] as String?);
};

/// Decodes a single JSON object.
Decoder<T> objectDecoder<T>(T Function(JsonMap json) build) =>
    (json) => build(json! as JsonMap);
