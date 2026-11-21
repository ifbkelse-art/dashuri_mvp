import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/level_progress.dart';
import '../../domain/entities/photo_upload_ticket.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

/// Default [ProfileRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<Profile>> getMyProfile() => _remote.getMyProfile();

  @override
  Future<Result<Profile>> updateMyProfile({
    required String? displayName,
    required String? bio,
    required List<String>? languages,
  }) => _remote.updateMyProfile(
    displayName: displayName,
    bio: bio,
    languages: languages,
  );

  @override
  Future<Result<Profile>> getProfile({required String userId}) =>
      _remote.getProfile(userId: userId);

  @override
  Future<Result<LevelProgress>> getMyLevel() => _remote.getMyLevel();

  @override
  Future<Result<PhotoUploadTicket>> requestPhotoUpload({
    required String contentType,
    required IdempotencyKey idempotencyKey,
  }) => _remote.requestPhotoUpload(
    contentType: contentType,
    idempotencyKey: idempotencyKey,
  );
}
