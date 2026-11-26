import 'package:dashuri_core/dashuri_core.dart';

import '../entities/arrival_photo.dart';
import '../entities/host_gift.dart';
import '../entities/host_photo.dart';
import '../repositories/host_session_repository.dart';

/// Ticket → upload → confirm for one captured photo. Each attempt uses a
/// fresh ticket (an abandoned one simply expires server-side), so a retry
/// after a network failure is always safe.
// Not final: application tests mock use cases.
class SubmitArrivalPhoto implements UseCase<ArrivalPhoto, PickedPhoto> {
  const SubmitArrivalPhoto(this._repository);

  final HostSessionRepository _repository;

  @override
  Future<Result<ArrivalPhoto>> call(PickedPhoto photo) async {
    if (photo.contentType != 'image/jpeg') {
      return const Err(
        ValidationFailure(fieldErrors: {'photo': 'must_be_image_jpeg'}),
      );
    }
    final ticket = await _repository.createArrivalUpload();
    switch (ticket) {
      case Err(:final failure):
        return Err(failure);
      case Success(:final value):
        if (photo.bytes.length > value.maxBytes) {
          return const Err(
            ValidationFailure(fieldErrors: {'photo': 'too_large'}),
          );
        }
        final up = await _repository.uploadArrival(value, photo);
        if (up case Err(:final failure)) return Err(failure);
        return _repository.confirmArrival(value.photoId);
    }
  }
}

// Not final: application tests mock use cases.
class GetArrivalPhoto implements UseCase<ArrivalPhoto?, NoInput> {
  const GetArrivalPhoto(this._repository);

  final HostSessionRepository _repository;

  @override
  Future<Result<ArrivalPhoto?>> call(NoInput input) =>
      _repository.currentArrival();
}

// Not final: application tests mock use cases.
class RemoveArrivalPhoto implements UseCase<void, NoInput> {
  const RemoveArrivalPhoto(this._repository);

  final HostSessionRepository _repository;

  @override
  Future<Result<void>> call(NoInput input) => _repository.removeArrival();
}

// Not final: application tests mock use cases.
class GetReceivedGifts implements UseCase<Page<ReceivedGift>, PageRequest> {
  const GetReceivedGifts(this._repository);

  final HostSessionRepository _repository;

  @override
  Future<Result<Page<ReceivedGift>>> call(PageRequest input) =>
      _repository.receivedGifts(input);
}

// Not final: application tests mock use cases.
class GetReceivedGiftSummary implements UseCase<ReceivedGiftSummary, NoInput> {
  const GetReceivedGiftSummary(this._repository);

  final HostSessionRepository _repository;

  @override
  Future<Result<ReceivedGiftSummary>> call(NoInput input) =>
      _repository.receivedGiftSummary();
}
