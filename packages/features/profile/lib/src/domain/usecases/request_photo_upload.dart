import 'package:dashuri_core/dashuri_core.dart';

import '../entities/photo_upload_ticket.dart';
import '../repositories/profile_repository.dart';

/// POST /v1/me/photos/upload-tickets
///
/// Value-moving or create action: pass the SAME [IdempotencyKey] for every
/// retry of one user intent; the server replays the first result.
// Not final: application tests mock use cases.
class RequestPhotoUpload
    implements
        UseCase<
          PhotoUploadTicket,
          ({String contentType, IdempotencyKey idempotencyKey})
        > {
  const RequestPhotoUpload(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<PhotoUploadTicket>> call(
    ({String contentType, IdempotencyKey idempotencyKey}) input,
  ) => _repository.requestPhotoUpload(
    contentType: input.contentType,
    idempotencyKey: input.idempotencyKey,
  );
}
