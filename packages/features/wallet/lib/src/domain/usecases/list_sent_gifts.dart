import 'package:dashuri_core/dashuri_core.dart';

import '../entities/sent_gift.dart';
import '../repositories/sent_gifts_repository.dart';

/// GET /v1/me/gifts/sent
// Not final: application tests mock use cases.
class ListSentGifts implements UseCase<Page<SentGift>, PageRequest> {
  const ListSentGifts(this._repository);

  final SentGiftsRepository _repository;

  @override
  Future<Result<Page<SentGift>>> call(PageRequest input) =>
      _repository.sentGifts(input);
}
