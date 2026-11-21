import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/free_call_card.dart';
import '../../domain/entities/free_call_request.dart';
import '../../domain/repositories/free_call_repository.dart';
import '../datasources/free_call_remote_data_source.dart';

/// Default [FreeCallRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class FreeCallRepositoryImpl implements FreeCallRepository {
  const FreeCallRepositoryImpl(this._remote);

  final FreeCallRemoteDataSource _remote;

  @override
  Future<Result<FreeCallCard>> getFreeCallCard() => _remote.getFreeCallCard();

  @override
  Future<Result<FreeCallRequest>> requestFreeCall({
    required IdempotencyKey idempotencyKey,
  }) => _remote.requestFreeCall(idempotencyKey: idempotencyKey);

  @override
  Future<Result<FreeCallRequest>> getFreeCallRequest({
    required String requestId,
  }) => _remote.getFreeCallRequest(requestId: requestId);
}
