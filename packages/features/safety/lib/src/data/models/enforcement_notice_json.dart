import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/enforcement_notice.dart';

/// Maps the API's snake_case JSON to [EnforcementNotice]. Keep in sync with api/openapi/dashuri.v1.yaml.
EnforcementNotice enforcementNoticeFromJson(JsonMap json) => EnforcementNotice(
  id: json['id']! as String,
  action: json['action']! as String,
  reason: json['reason']! as String,
  createdAt: DateTime.parse(json['created_at']! as String),
  appealable: json['appealable']! as bool,
);
