import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/call_credentials.dart';
import '../../domain/entities/call_event.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/entities/pre_call_info.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_remote_data_source.dart';
import '../models/call_json.dart';

final class CallRepositoryImpl implements CallRepository {
  const CallRepositoryImpl(
    this._remote,
    this._realtime, {
    String? Function()? currentUserId,
  }) : _currentUserId = currentUserId;

  final CallRemoteDataSource _remote;
  final RealtimeGateway _realtime;

  /// Signed-in user id, used to read `call:<id>` events (caller's view).
  final String? Function()? _currentUserId;

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
      .map((e) => _safeEvent(e, _currentUserId?.call()))
      .where((e) => e != null)
      .cast<CallEvent>();

  @override
  Stream<CallSession> watchUserCalls(String userId) => _realtime
      .subscribe('user:$userId')
      .where((e) => e.type == 'call.updated')
      .map((e) => _safeEvent(e, null))
      .whereType<CallUpdated>()
      .map((e) => e.session);

  @override
  Future<Result<bool>> submitModerationFrame({
    required String callId,
    required String imageBase64,
    required DateTime capturedAt,
  }) => _remote.moderationFrame(callId, imageBase64, capturedAt);

  @override
  Future<Result<Page<CallSession>>> callHistory(PageRequest page) =>
      _remote.history(page);

  @override
  Future<Result<PreCallInfo>> preCallInfo(String hostUserId) async {
    final results = await Future.wait([
      _remote.host(hostUserId),
      _remote.wallet(),
      _remote.packages(),
    ]);
    final host = results[0], wallet = results[1], packages = results[2];
    if (host case Err(:final failure)) return Err(failure);
    if (wallet case Err(:final failure)) return Err(failure);
    try {
      return Success(
        preCallInfoFromJson(
          host: (host as Success<JsonMap>).value,
          wallet: (wallet as Success<JsonMap>).value,
          // The ₹ hint is optional; a failed catalogue call only hides it.
          packages: packages is Success<JsonMap> ? packages.value : null,
        ),
      );
    } on TypeError catch (e) {
      return Err(UnexpectedFailure(message: 'Response did not match: $e'));
    }
  }

  @override
  Future<Result<int>> availableDiamonds() async {
    final wallet = await _remote.wallet();
    return switch (wallet) {
      Success(:final value) when value['available_diamonds'] is num => Success(
        (value['available_diamonds']! as num).toInt(),
      ),
      Success() => const Err(
        UnexpectedFailure(message: 'available_diamonds missing'),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  /// A malformed realtime payload is a hint lost, not a crash.
  static CallEvent? _safeEvent(RealtimeEvent e, String? selfUserId) {
    try {
      return callEventFromRealtime(e, selfUserId: selfUserId);
    } on Object {
      return null;
    }
  }
}

extension<T> on Stream<T> {
  Stream<R> whereType<R>() => where((e) => e is R).cast<R>();
}
