import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_photo.dart';
import '../../domain/entities/host_profile.dart';

/// Maps `Profile` (GET/PATCH /v1/me/profile) to [HostProfile].
HostProfile hostProfileFromJson(JsonMap json) => HostProfile(
  userId: json['user_id']! as String,
  displayName: json['display_name']! as String,
  bio: json['bio'] as String?,
  languages: (json['languages']! as List<Object?>).cast<String>(),
  photoUrls: (json['photo_urls']! as List<Object?>).cast<String>(),
  isHost: json['is_host']! as bool,
  level: json['level']! as int,
);

/// `UpdateProfileRequest` body. An empty bio clears it (null).
JsonMap updateProfileToJson({
  required String displayName,
  required String? bio,
  required List<String> languages,
}) => {
  'display_name': displayName.trim(),
  'bio': (bio == null || bio.trim().isEmpty) ? null : bio.trim(),
  'languages': languages,
};

/// Maps `PhotoUploadTicket`.
PhotoUploadTicket photoUploadTicketFromJson(JsonMap json) => PhotoUploadTicket(
  photoId: json['photo_id']! as String,
  uploadUrl: Uri.parse(json['upload_url']! as String),
  expiresAt: DateTime.parse(json['expires_at']! as String),
);
