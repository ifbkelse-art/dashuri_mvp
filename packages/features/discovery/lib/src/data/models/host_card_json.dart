import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_card.dart';

/// Maps the API's snake_case JSON to [HostCard]. Keep in sync with api/openapi/dashuri.v1.yaml.
HostCard hostCardFromJson(JsonMap json) => HostCard(
  userId: json['user_id']! as String,
  displayName: json['display_name']! as String,
  photoUrl: json['photo_url'] as String?,
  languages: (json['languages']! as List<Object?>).cast<String>(),
  level: json['level']! as int,
  ratePerMinute: json['rate_per_minute']! as int,
  availability: json['availability']! as String,
);
