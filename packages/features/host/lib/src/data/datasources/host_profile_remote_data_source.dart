import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_call.dart';
import '../../domain/entities/host_photo.dart';
import '../../domain/entities/host_profile.dart';
import '../models/host_call_json.dart';
import '../models/host_profile_json.dart';

/// The host feature's own access to profile, photo-ticket and call-history
/// endpoints (features never import each other).
final class HostProfileRemoteDataSource {
  const HostProfileRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<HostProfile>> getMyProfile() =>
      _api.get('/v1/me/profile', decode: objectDecoder(hostProfileFromJson));

  Future<Result<HostProfile>> updateMyProfile({
    required String displayName,
    required String? bio,
    required List<String> languages,
  }) => _api.patch(
    '/v1/me/profile',
    decode: objectDecoder(hostProfileFromJson),
    body: updateProfileToJson(
      displayName: displayName,
      bio: bio,
      languages: languages,
    ),
  );

  Future<Result<PhotoUploadTicket>> requestPhotoUpload({
    required String contentType,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/me/photos/upload-tickets',
    decode: objectDecoder(photoUploadTicketFromJson),
    body: {'content_type': contentType},
    idempotencyKey: idempotencyKey,
  );

  Future<Result<Page<HostCall>>> listCallHistory({
    required PageRequest page,
  }) => _api.get(
    '/v1/calls/history',
    decode: pageDecoder(hostCallFromJson),
    query: page.toQuery(),
  );
}
