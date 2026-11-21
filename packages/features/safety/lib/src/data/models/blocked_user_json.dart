import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/blocked_user.dart';

/// Maps the API's snake_case JSON to [BlockedUser]. Keep in sync with api/openapi/dashuri.v1.yaml.
BlockedUser blockedUserFromJson(JsonMap json) => BlockedUser(
  userId: json['user_id']! as String,
  displayName: json['display_name']! as String,
  blockedAt: DateTime.parse(json['blocked_at']! as String),
);
