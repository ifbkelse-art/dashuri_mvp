import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/profile.dart';

/// Maps the API's snake_case JSON to [Profile]. Keep in sync with
/// api/openapi/dashuri.v1.yaml and the MVP contract (gender, city).
Profile profileFromJson(JsonMap json) => Profile(
  userId: json['user_id']! as String,
  displayName: json['display_name']! as String,
  bio: json['bio'] as String?,
  languages: (json['languages']! as List<Object?>).cast<String>(),
  photoUrls: (json['photo_urls']! as List<Object?>).cast<String>(),
  isHost: json['is_host']! as bool,
  level: json['level']! as int,
  gender: Gender.fromWire(json['gender'] as String?),
  city: json['city'] == null
      ? null
      : profileCityFromJson(json['city']! as JsonMap),
);

ProfileCity profileCityFromJson(JsonMap json) => ProfileCity(
  id: json['id']! as String,
  name: json['name']! as String,
  state: (json['state'] as String?) ?? '',
);

/// Request body for PATCH /v1/me/profile.
JsonMap profileUpdateToJson(ProfileUpdate u) => {
  'display_name': ?u.displayName,
  'bio': ?u.bio,
  'languages': ?u.languages,
  'gender': ?u.gender?.wire,
  if (u.clearCity) 'city_id': null else 'city_id': ?u.cityId,
};
