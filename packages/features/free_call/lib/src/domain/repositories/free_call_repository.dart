import 'package:dashuri_core/dashuri_core.dart';

import '../entities/free_call_card.dart';
import '../entities/free_call_request.dart';

/// Contract for free call data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class FreeCallRepository {
  Future<Result<FreeCallCard>> getFreeCallCard();

  Future<Result<FreeCallRequest>> requestFreeCall({
    required IdempotencyKey idempotencyKey,
    String? integrityToken,
  });

  Future<Result<FreeCallRequest>> getFreeCallRequest({
    required String requestId,
  });
}
