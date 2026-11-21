import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/free_call_card.dart';

/// Maps the API's snake_case JSON to [FreeCallCard]. Keep in sync with api/openapi/dashuri.v1.yaml.
FreeCallCard freeCallCardFromJson(JsonMap json) => FreeCallCard(
  status: json['status']! as String,
  usedAt: json['used_at'] == null
      ? null
      : DateTime.parse(json['used_at']! as String),
);
