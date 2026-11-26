import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/arrival_photo.dart';
import '../../domain/entities/host_gift.dart';
import '../../domain/entities/host_photo.dart';
import '../../domain/repositories/host_session_repository.dart';
import '../datasources/host_session_remote_data_source.dart';
import '../datasources/photo_upload_data_source.dart';

final class HostSessionRepositoryImpl implements HostSessionRepository {
  const HostSessionRepositoryImpl(this._remote, this._uploads);

  final HostSessionRemoteDataSource _remote;
  final PhotoUploadDataSource _uploads;

  @override
  Future<Result<ArrivalUploadTicket>> createArrivalUpload() =>
      _remote.createArrivalUpload();

  @override
  Future<Result<void>> uploadArrival(
    ArrivalUploadTicket ticket,
    PickedPhoto photo,
  ) => _uploads.upload(
    ticket: PhotoUploadTicket(
      photoId: ticket.photoId,
      uploadUrl: ticket.uploadUrl,
      expiresAt: ticket.expiresAt,
    ),
    photo: photo,
  );

  @override
  Future<Result<ArrivalPhoto>> confirmArrival(String photoId) =>
      _remote.confirmArrival(photoId);

  @override
  Future<Result<ArrivalPhoto?>> currentArrival() => _remote.currentArrival();

  @override
  Future<Result<void>> removeArrival() => _remote.removeArrival();

  @override
  Future<Result<Page<ReceivedGift>>> receivedGifts(PageRequest page) =>
      _remote.receivedGifts(page);

  @override
  Future<Result<ReceivedGiftSummary>> receivedGiftSummary() =>
      _remote.receivedGiftSummary();
}
