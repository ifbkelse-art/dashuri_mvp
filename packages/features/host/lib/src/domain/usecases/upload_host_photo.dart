import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_photo.dart';
import '../repositories/host_repository.dart';

/// Requests a signed upload ticket and uploads the photo bytes to it. The
/// photo stays private until moderated.
// Not final: application tests mock use cases.
class UploadHostPhoto
    implements
        UseCase<
          PhotoUploadTicket,
          ({PickedPhoto photo, IdempotencyKey idempotencyKey})
        > {
  const UploadHostPhoto(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<PhotoUploadTicket>> call(
    ({PickedPhoto photo, IdempotencyKey idempotencyKey}) input,
  ) {
    if (!PickedPhoto.allowedContentTypes.contains(input.photo.contentType)) {
      return Future.value(
        const Err(
          ValidationFailure(
            fieldErrors: {'content_type': 'unsupported'},
            message: 'Only JPEG, PNG or WebP photos can be uploaded.',
          ),
        ),
      );
    }
    return _repository.uploadPhoto(
      photo: input.photo,
      idempotencyKey: input.idempotencyKey,
    );
  }
}
