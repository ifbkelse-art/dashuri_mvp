import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/sent_gift.dart';
import '../../domain/repositories/sent_gifts_repository.dart';
import '../models/sent_gift_json.dart';

final class SentGiftsRepositoryImpl implements SentGiftsRepository {
  const SentGiftsRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<Page<SentGift>>> sentGifts(PageRequest page) => _api.get(
    '/v1/me/gifts/sent',
    decode: pageDecoder(sentGiftFromJson),
    query: page.toQuery(),
  );
}
