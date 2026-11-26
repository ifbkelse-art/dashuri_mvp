import 'package:dashuri_core/dashuri_core.dart';

import '../entities/gift.dart';
import '../repositories/gift_repository.dart';

/// GET /v1/gifts/catalogue
// Not final: application tests mock use cases.
class GetGiftCatalogue implements UseCase<List<Gift>, NoInput> {
  const GetGiftCatalogue(this._repository);

  final GiftRepository _repository;

  @override
  Future<Result<List<Gift>>> call(NoInput input) => _repository.catalogue();
}

/// Input for [SendGift]. No price: the server prices the gift.
final class SendGiftInput {
  const SendGiftInput({
    required this.callId,
    required this.giftId,
    required this.recipientUserId,
    required this.idempotencyKey,
  });

  final String callId;
  final String giftId;
  final String recipientUserId;
  final IdempotencyKey idempotencyKey;
}

/// POST /v1/calls/{callId}/gifts
// Not final: application tests mock use cases.
class SendGift implements UseCase<GiftReceipt, SendGiftInput> {
  const SendGift(this._repository);

  final GiftRepository _repository;

  @override
  Future<Result<GiftReceipt>> call(SendGiftInput input) => _repository.send(
    callId: input.callId,
    giftId: input.giftId,
    recipientUserId: input.recipientUserId,
    idempotencyKey: input.idempotencyKey,
  );
}

/// GET /v1/calls/{callId}/gifts
// Not final: application tests mock use cases.
class GetCallGifts implements UseCase<List<GiftEvent>, String> {
  const GetCallGifts(this._repository);

  final GiftRepository _repository;

  @override
  Future<Result<List<GiftEvent>>> call(String callId) =>
      _repository.callGifts(callId);
}

/// `call.gift` realtime hints for one call.
// Not final: application tests mock use cases.
class WatchCallGifts implements StreamUseCase<GiftEvent, String> {
  const WatchCallGifts(this._repository);

  final GiftRepository _repository;

  @override
  Stream<GiftEvent> call(String callId) => _repository.watchCallGifts(callId);
}

/// The customer's available Diamonds, for the gift sheet.
// Not final: application tests mock use cases.
class GetGiftBalance implements UseCase<int, NoInput> {
  const GetGiftBalance(this._repository);

  final GiftRepository _repository;

  @override
  Future<Result<int>> call(NoInput input) => _repository.availableDiamonds();
}
