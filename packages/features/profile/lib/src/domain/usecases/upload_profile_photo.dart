import 'package:dashuri_core/dashuri_core.dart';

import '../ports/photo_picker.dart';
import '../repositories/profile_repository.dart';

/// POST /v1/me/photos/upload-tickets, then PUT the bytes to the signed URL.
/// The photo stays private until moderated. Returns the new photo id.
// Not final: application tests mock use cases.
class UploadProfilePhoto
    implements
        UseCase<String, ({PickedPhoto photo, IdempotencyKey idempotencyKey})> {
  const UploadProfilePhoto(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<String>> call(
    ({PickedPhoto photo, IdempotencyKey idempotencyKey}) input,
  ) async {
    final ticket = await _repository.requestPhotoUpload(
      contentType: input.photo.contentType,
      idempotencyKey: input.idempotencyKey,
    );
    switch (ticket) {
      case Err(:final failure):
        return Err(failure);
      case Success(:final value):
        final upload = await _repository.uploadPhotoBytes(
          ticket: value,
          bytes: input.photo.bytes,
          contentType: input.photo.contentType,
        );
        return upload.map((_) => value.photoId);
    }
  }
}
