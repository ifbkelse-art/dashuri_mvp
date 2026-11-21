import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/level_progress.dart';
import '../../domain/entities/photo_upload_ticket.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

/// Default [ProfileRepository]: delegates to the API.
final class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<Profile>> getMyProfile() => _remote.getMyProfile();

  @override
  Future<Result<Profile>> updateMyProfile(ProfileUpdate update) =>
      _remote.updateMyProfile(update);

  @override
  Future<Result<Profile>> getProfile({required String userId}) =>
      _remote.getProfile(userId: userId);

  @override
  Future<Result<LevelProgress>> getMyLevel() => _remote.getMyLevel();

  @override
  Future<Result<int>> getAvailableDiamonds() => _remote.getAvailableDiamonds();

  @override
  Future<Result<PhotoUploadTicket>> requestPhotoUpload({
    required String contentType,
    required IdempotencyKey idempotencyKey,
  }) => _remote.requestPhotoUpload(
    contentType: contentType,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<void>> uploadPhotoBytes({
    required PhotoUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
  }) => _remote.uploadBytes(
    uploadUrl: ticket.uploadUrl,
    bytes: bytes,
    contentType: contentType,
  );
}
