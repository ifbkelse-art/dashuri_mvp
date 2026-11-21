import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_card.dart';

City? cityFromJson(Object? json) {
  if (json is! Map<String, Object?>) return null;
  final id = json['id'], name = json['name'];
  if (id is! String || name is! String) return null;
  return City(id: id, name: name, state: json['state'] as String?);
}

/// Maps the API's snake_case JSON to [HostCard]. Keep in sync with
/// api/openapi/dashuri.v1.yaml and the MVP contract 2.3 (optional fields).
HostCard hostCardFromJson(JsonMap json) => HostCard(
  userId: json['user_id']! as String,
  displayName: json['display_name']! as String,
  photoUrl: json['photo_url'] as String?,
  languages: (json['languages']! as List<Object?>).cast<String>(),
  level: (json['level']! as num).toInt(),
  ratePerMinute: (json['rate_per_minute']! as num).toInt(),
  availability: json['availability']! as String,
  city: cityFromJson(json['city']),
  age: (json['age'] as num?)?.toInt(),
  isVerified: json['is_verified'] as bool? ?? false,
);

/// Host detail: HostCard + `bio` (+ optional `photo_urls`).
HostProfile hostProfileFromJson(JsonMap json) => HostProfile(
  card: hostCardFromJson(json),
  bio: json['bio'] as String?,
  photoUrls: (json['photo_urls'] as List<Object?>?)?.cast<String>() ?? const [],
);
