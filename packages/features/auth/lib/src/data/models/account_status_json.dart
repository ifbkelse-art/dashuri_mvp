import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/account_status.dart';

/// GET /v1/me (MVP contract 2.1 adds profile_complete, rules_accepted and
/// host_state). Missing onboarding flags are treated as "not done yet".
AccountStatus accountStatusFromJson(JsonMap json) => AccountStatus(
  userId: json['user_id']! as String,
  ageEligible: json['age_eligible']! as bool,
  isHost: json['is_host']! as bool,
  restriction: json['restriction'] as String?,
  profileComplete: (json['profile_complete'] as bool?) ?? false,
  rulesAccepted: (json['rules_accepted'] as bool?) ?? false,
  hostState: json['host_state'] as String?,
);
