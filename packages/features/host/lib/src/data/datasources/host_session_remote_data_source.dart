import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/arrival_photo.dart';
import '../../domain/entities/host_gift.dart';
import '../models/session_json.dart';

// Not final: repository tests mock it.
class HostSessionRemoteDataSource {
  const HostSessionRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<ArrivalUploadTicket>> createArrivalUpload() => _api.post(
    '/v1/host/arrival-photo/upload-tickets',
    decode: objectDecoder(arrivalTicketFromJson),
    body: {'content_type': 'image/jpeg'},
  );

  Future<Result<ArrivalPhoto>> confirmArrival(String photoId) => _api.post(
    '/v1/host/arrival-photo/$photoId/confirm',
    decode: objectDecoder(arrivalPhotoFromJson),
  );

  /// 204 (no photo in this session) decodes to null.
  Future<Result<ArrivalPhoto?>> currentArrival() => _api.get(
    '/v1/host/arrival-photo',
    decode: (j) => j is JsonMap ? arrivalPhotoFromJson(j) : null,
  );

  Future<Result<void>> removeArrival() => _api.delete('/v1/host/arrival-photo');

  Future<Result<Page<ReceivedGift>>> receivedGifts(PageRequest page) =>
      _api.get(
        '/v1/host/gifts',
        decode: pageDecoder(receivedGiftFromJson),
        query: page.toQuery(),
      );

  Future<Result<ReceivedGiftSummary>> receivedGiftSummary() => _api.get(
    '/v1/host/gifts/summary',
    decode: objectDecoder(receivedGiftSummaryFromJson),
  );
}
