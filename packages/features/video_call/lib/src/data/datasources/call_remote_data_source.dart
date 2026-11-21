import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/call_credentials.dart';
import '../../domain/entities/call_session.dart';
import '../models/call_json.dart';

final class CallRemoteDataSource {
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
}
