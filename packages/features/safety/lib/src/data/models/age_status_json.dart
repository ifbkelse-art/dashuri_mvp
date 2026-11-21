import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/age_status.dart';

/// Maps the API's snake_case JSON to [AgeStatus]. Keep in sync with api/openapi/dashuri.v1.yaml.
AgeStatus ageStatusFromJson(JsonMap json) => AgeStatus(
  eligible: json['eligible']! as bool,
  method: json['method'] as String?,
);
