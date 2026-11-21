import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/free_call_card.dart';
import '../../domain/entities/free_call_request.dart';
import '../models/free_call_card_json.dart';
import '../models/free_call_request_json.dart';

/// HTTP access to the free call endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class FreeCallRemoteDataSource {
  const FreeCallRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<FreeCallCard>> getFreeCallCard() => _api.get(
    '/v1/free-call/card',
    decode: objectDecoder(freeCallCardFromJson),
  );

  Future<Result<FreeCallRequest>> requestFreeCall({
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/free-call/requests',
    decode: objectDecoder(freeCallRequestFromJson),
    idempotencyKey: idempotencyKey,
  );

  Future<Result<FreeCallRequest>> getFreeCallRequest({
    required String requestId,
  }) => _api.get(
    '/v1/free-call/requests/$requestId',
    decode: objectDecoder(freeCallRequestFromJson),
  );
}
