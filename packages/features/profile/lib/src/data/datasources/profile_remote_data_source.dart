import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/level_progress.dart';
import '../../domain/entities/photo_upload_ticket.dart';
import '../../domain/entities/profile.dart';
import '../models/level_progress_json.dart';
import '../models/photo_upload_ticket_json.dart';
import '../models/profile_json.dart';

/// HTTP access to the profile endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class ProfileRemoteDataSource {
  const ProfileRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<Profile>> getMyProfile() =>
      _api.get('/v1/me/profile', decode: objectDecoder(profileFromJson));

  Future<Result<Profile>> updateMyProfile({
    required String? displayName,
    required String? bio,
    required List<String>? languages,
  }) => _api.patch(
    '/v1/me/profile',
    decode: objectDecoder(profileFromJson),
    body: {'display_name': ?displayName, 'bio': ?bio, 'languages': ?languages},
  );

  Future<Result<Profile>> getProfile({required String userId}) =>
      _api.get('/v1/profiles/$userId', decode: objectDecoder(profileFromJson));

  Future<Result<LevelProgress>> getMyLevel() =>
      _api.get('/v1/me/level', decode: objectDecoder(levelProgressFromJson));

  Future<Result<PhotoUploadTicket>> requestPhotoUpload({
    required String contentType,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/me/photos/upload-tickets',
    decode: objectDecoder(photoUploadTicketFromJson),
    body: {'content_type': contentType},
    idempotencyKey: idempotencyKey,
  );
}
