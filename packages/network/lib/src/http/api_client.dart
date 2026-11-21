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

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    required Decoder<T> decode,
    Map<String, String>? query,
    JsonMap? body,
    IdempotencyKey? idempotencyKey,
  }) async {
    try {
      final token = await _tokens.accessToken();
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
