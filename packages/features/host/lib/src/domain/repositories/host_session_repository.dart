import 'package:dashuri_core/dashuri_core.dart';

import '../entities/arrival_photo.dart';
import '../entities/host_gift.dart';
import '../entities/host_photo.dart';

/// Arrival photos (current online session) and received gifts.
abstract interface class HostSessionRepository {
  /// POST /v1/host/arrival-photo/upload-tickets (JPEG only).
  Future<Result<ArrivalUploadTicket>> createArrivalUpload();

  /// PUT the bytes to the signed URL (no bearer token).
  Future<Result<void>> uploadArrival(
    ArrivalUploadTicket ticket,
    PickedPhoto photo,
  );

  /// POST /v1/host/arrival-photo/{id}/confirm — the server validates,
  /// re-encodes and moderates the upload.
  Future<Result<ArrivalPhoto>> confirmArrival(String photoId);

  /// GET /v1/host/arrival-photo (null when the session has none).
  Future<Result<ArrivalPhoto?>> currentArrival();

  /// DELETE /v1/host/arrival-photo.
  Future<Result<void>> removeArrival();

  Future<Result<Page<ReceivedGift>>> receivedGifts(PageRequest page);

  Future<Result<ReceivedGiftSummary>> receivedGiftSummary();
}
