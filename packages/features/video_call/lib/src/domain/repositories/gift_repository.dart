import 'package:dashuri_core/dashuri_core.dart';

import '../entities/gift.dart';

/// Virtual gifts during a call. The server prices, charges and records every
/// gift; this contract never carries an amount to the server.
abstract interface class GiftRepository {
  /// GET /v1/gifts/catalogue — gifts that can be sent now.
  Future<Result<List<Gift>>> catalogue();

  /// POST /v1/calls/{callId}/gifts with [idempotencyKey] (UUIDv4, one per
  /// tap on Send, reused for every retry of that tap).
  Future<Result<GiftReceipt>> send({
    required String callId,
    required String giftId,
    required String recipientUserId,
    required IdempotencyKey idempotencyKey,
  });

  /// GET /v1/calls/{callId}/gifts — the canonical history, oldest first.
  Future<Result<List<GiftEvent>>> callGifts(String callId);

  /// `call.gift` events on `call:<id>` (hints; may repeat or be lost).
  Stream<GiftEvent> watchCallGifts(String callId);

  /// The customer's available Diamonds (GET /v1/wallet).
  Future<Result<int>> availableDiamonds();
}
