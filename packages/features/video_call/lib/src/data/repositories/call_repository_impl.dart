import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/call_credentials.dart';
import '../../domain/entities/call_event.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_remote_data_source.dart';
import '../models/call_json.dart';

final class CallRepositoryImpl implements CallRepository {
  const CallRepositoryImpl(this._remote, this._realtime);

  final CallRemoteDataSource _remote;
  final RealtimeGateway _realtime;

  @override
  Future<Result<CallSession>> requestCall({
    required String hostUserId,
    required IdempotencyKey idempotencyKey,
  }) => _remote.requestCall(hostUserId, idempotencyKey);

  @override
  Future<Result<CallSession>> acceptCall(String callId) =>
      _remote.accept(callId);

  @override
  Future<Result<CallSession>> declineCall(String callId) =>
      _remote.decline(callId);

  @override
  Future<Result<CallSession>> endCall({
    required String callId,
    required String reason,
    required IdempotencyKey idempotencyKey,
  }) => _remote.end(callId, reason, idempotencyKey);

  @override
  Future<Result<CallSession>> getCall(String callId) => _remote.get(callId);

  @override
  Future<Result<CallCredentials>> getCredentials(String callId) =>
      _remote.credentials(callId);

  @override
  Stream<CallEvent> watchCall(String callId) => _realtime
      .subscribe('call:$callId')
      .map(callEventFromRealtime)
      .where((e) => e != null)
      .cast<CallEvent>();
}
