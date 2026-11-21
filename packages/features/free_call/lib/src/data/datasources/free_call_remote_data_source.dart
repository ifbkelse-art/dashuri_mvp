import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/free_call_card.dart';
import '../../domain/entities/free_call_request.dart';
import '../models/free_call_card_json.dart';
import '../models/free_call_request_json.dart';

/// HTTP access to the free call endpoints of the Go API.
///
/// The server reads the client platform from `X-Client-Platform` or the
/// request body's `platform`. `ApiClient` has no per-request headers, so
/// the request body carries `platform`.
// Not final: repository tests mock it.
class FreeCallRemoteDataSource {
  const FreeCallRemoteDataSource(this._api, {this.platform = 'android'});

  final ApiClient _api;

  /// `android` or `ios`.
  final String platform;

  Future<Result<FreeCallCard>> getFreeCallCard() => _api.get(
    '/v1/free-call/card',
    decode: objectDecoder(freeCallCardFromJson),
  );

  Future<Result<FreeCallRequest>> requestFreeCall({
    required IdempotencyKey idempotencyKey,
    String? integrityToken,
  }) => _api.post(
    '/v1/free-call/requests',
    decode: objectDecoder(freeCallRequestFromJson),
    body: {'play_integrity_token': integrityToken, 'platform': platform},
    idempotencyKey: idempotencyKey,
  );

  Future<Result<FreeCallRequest>> getFreeCallRequest({
    required String requestId,
  }) => _api.get(
    '/v1/free-call/requests/$requestId',
    decode: objectDecoder(freeCallRequestFromJson),
  );
}
