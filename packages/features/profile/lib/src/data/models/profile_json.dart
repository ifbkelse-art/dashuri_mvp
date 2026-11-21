import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/profile.dart';

/// Maps the API's snake_case JSON to [Profile]. Keep in sync with api/openapi/dashuri.v1.yaml.
Profile profileFromJson(JsonMap json) => Profile(
  userId: json['user_id']! as String,
  displayName: json['display_name']! as String,
  bio: json['bio'] as String?,
  languages: (json['languages']! as List<Object?>).cast<String>(),
  photoUrls: (json['photo_urls']! as List<Object?>).cast<String>(),
  isHost: json['is_host']! as bool,
  level: json['level']! as int,
);
