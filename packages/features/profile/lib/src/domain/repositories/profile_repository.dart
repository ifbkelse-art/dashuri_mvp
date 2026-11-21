import 'package:dashuri_core/dashuri_core.dart';

import '../entities/level_progress.dart';
import '../entities/photo_upload_ticket.dart';
import '../entities/profile.dart';

/// Contract for profile data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class ProfileRepository {
  Future<Result<Profile>> getMyProfile();

  Future<Result<Profile>> updateMyProfile({
    required String? displayName,
    required String? bio,
    required List<String>? languages,
  });

  Future<Result<Profile>> getProfile({required String userId});

  Future<Result<LevelProgress>> getMyLevel();

  Future<Result<PhotoUploadTicket>> requestPhotoUpload({
    required String contentType,
    required IdempotencyKey idempotencyKey,
  });
}
