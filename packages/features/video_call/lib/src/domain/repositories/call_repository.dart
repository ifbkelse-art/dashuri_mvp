import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_credentials.dart';
import '../entities/call_event.dart';
import '../entities/call_session.dart';
import '../entities/pre_call_info.dart';

/// Call lifecycle through the Go API. The server decides authorisation,
/// connection, billable time and settlement.
abstract interface class CallRepository {
  /// Customer calls a host. Server checks: both eligible, host available,
  /// not blocked, no other active call, balance ≥ 60 s at the host's rate.
  Future<Result<CallSession>> requestCall({
    required String hostUserId,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<CallSession>> acceptCall(String callId);

  Future<Result<CallSession>> declineCall(String callId);

  /// Either party ends the call at any time (C15). Settlement happens on the server.
  Future<Result<CallSession>> endCall({
    required String callId,
    required String reason,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<CallSession>> getCall(String callId);

  Future<Result<CallCredentials>> getCredentials(String callId);

  Stream<CallEvent> watchCall(String callId);

  /// `call.updated` events on `user:<userId>` (incoming rings for hosts).
  Stream<CallSession> watchUserCalls(String userId);

  /// POST /v1/calls/{id}/moderation-frames (S7).
  Future<Result<void>> submitModerationFrame({
    required String callId,
    required String imageBase64,
    required DateTime capturedAt,
  });

  /// GET /v1/calls/history.
  Future<Result<Page<CallSession>>> callHistory(PageRequest page);

  /// Host rate + own balance for the pre-call screen (V01/V06).
  Future<Result<PreCallInfo>> preCallInfo(String hostUserId);

  /// Own available Diamonds (GET /v1/wallet), for summaries.
  Future<Result<int>> availableDiamonds();
}
