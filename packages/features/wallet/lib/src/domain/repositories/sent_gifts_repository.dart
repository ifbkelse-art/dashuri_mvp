import 'package:dashuri_core/dashuri_core.dart';

import '../entities/sent_gift.dart';

abstract interface class SentGiftsRepository {
  Future<Result<Page<SentGift>>> sentGifts(PageRequest page);
}
