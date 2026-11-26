import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/gift.dart';
import '../models/gift_json.dart';

// Not final: repository tests mock it.
class GiftRemoteDataSource {
  const GiftRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<List<Gift>>> catalogue() => _api.get(
    '/v1/gifts/catalogue',
    decode: objectDecoder(giftCatalogueFromJson),
  );

  /// The body names the gift and the recipient only; never a price.
  Future<Result<GiftReceipt>> send(
    String callId,
    String giftId,
    String recipientUserId,
    IdempotencyKey key,
  ) => _api.post(
    '/v1/calls/$callId/gifts',
    decode: objectDecoder(giftReceiptFromJson),
    body: {'gift_id': giftId, 'recipient_user_id': recipientUserId},
    idempotencyKey: key,
  );

  Future<Result<List<GiftEvent>>> callGifts(String callId) => _api.get(
    '/v1/calls/$callId/gifts',
    decode: objectDecoder(giftEventsFromJson),
  );

  Future<Result<JsonMap>> wallet() =>
      _api.get('/v1/wallet', decode: objectDecoder((j) => j));
}
