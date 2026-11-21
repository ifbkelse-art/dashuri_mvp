import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/consent_state.dart';

/// Maps the API's snake_case JSON to [ConsentState]. Keep in sync with api/openapi/dashuri.v1.yaml.
ConsentState consentStateFromJson(JsonMap json) => ConsentState(
  analytics: json['analytics']! as bool,
  marketing: json['marketing']! as bool,
  updatedAt: DateTime.parse(json['updated_at']! as String),
);
