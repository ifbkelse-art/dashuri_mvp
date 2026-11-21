import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/call_credentials.dart';
import '../../domain/entities/call_session.dart';
import '../models/call_json.dart';

// Not final: repository tests mock it.
class CallRemoteDataSource {
  const CallRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<CallSession>> requestCall(
    String hostUserId,
    IdempotencyKey key,
  ) => _api.post(
    '/v1/calls',
    decode: objectDecoder(callSessionFromJson),
    body: {'host_user_id': hostUserId},
    idempotencyKey: key,
  );

  Future<Result<CallSession>> accept(String callId) => _api.post(
    '/v1/calls/$callId/accept',
    decode: objectDecoder(callSessionFromJson),
  );

  Future<Result<CallSession>> decline(String callId) => _api.post(
    '/v1/calls/$callId/decline',
    decode: objectDecoder(callSessionFromJson),
  );

  Future<Result<CallSession>> end(
    String callId,
    String reason,
    IdempotencyKey key,
  ) => _api.post(
    '/v1/calls/$callId/end',
    decode: objectDecoder(callSessionFromJson),
    body: {'reason': reason},
    idempotencyKey: key,
  );

  Future<Result<CallSession>> get(String callId) =>
      _api.get('/v1/calls/$callId', decode: objectDecoder(callSessionFromJson));

  Future<Result<CallCredentials>> credentials(String callId) => _api.post(
    '/v1/calls/$callId/credentials',
    decode: objectDecoder(callCredentialsFromJson),
  );

  Future<Result<void>> moderationFrame(
    String callId,
    String imageBase64,
    DateTime capturedAt,
  ) => _api.post<void>(
    '/v1/calls/$callId/moderation-frames',
    decode: (_) {},
    body: {
      'image_base64': imageBase64,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    },
  );

  Future<Result<Page<CallSession>>> history(PageRequest page) => _api.get(
    '/v1/calls/history',
    decode: pageDecoder(callSessionFromJson),
    query: page.toQuery(),
  );

  Future<Result<JsonMap>> host(String userId) => _api.get(
    '/v1/discovery/hosts/$userId',
    decode: objectDecoder((j) => j),
  );

  Future<Result<JsonMap>> wallet() =>
      _api.get('/v1/wallet', decode: objectDecoder((j) => j));

  Future<Result<JsonMap>> packages() =>
      _api.get('/v1/purchases/packages', decode: objectDecoder((j) => j));
}
