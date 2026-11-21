import 'package:dashuri_core/dashuri_core.dart';

import '../entities/level_progress.dart';
import '../entities/photo_upload_ticket.dart';
import '../entities/profile.dart';

/// Contract for profile data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class ProfileRepository {
  Future<Result<Profile>> getMyProfile();

  Future<Result<Profile>> updateMyProfile(ProfileUpdate update);

  Future<Result<Profile>> getProfile({required String userId});

  Future<Result<LevelProgress>> getMyLevel();

  /// Available Diamonds from GET /v1/wallet (S01 wallet shortcut).
  Future<Result<int>> getAvailableDiamonds();

  Future<Result<PhotoUploadTicket>> requestPhotoUpload({
    required String contentType,
    required IdempotencyKey idempotencyKey,
  });

  /// PUTs the bytes to the ticket's signed URL.
  Future<Result<void>> uploadPhotoBytes({
    required PhotoUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
  });
}
