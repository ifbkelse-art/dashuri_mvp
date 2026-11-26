import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_status.dart';

/// Maps the API's snake_case JSON to [HostStatus]. Keep in sync with
/// api/openapi/dashuri.v1.yaml and docs/mvp/MVP_DECISIONS_AND_CONTRACT.md 2.7.
HostStatus hostStatusFromJson(JsonMap json) => HostStatus(
  state: json['state']! as String,
  kycState: json['kyc_state']! as String,
  isAvailable: json['is_available']! as bool,
  ratePerMinute: json['rate_per_minute']! as int,
  minRatePerMinute: json['min_rate_per_minute']! as int,
  maxRatePerMinute: json['max_rate_per_minute']! as int,
  freeCallOptIn: json['free_call_opt_in']! as bool,
  todayEarnedBeans: json['today_earned_beans'] as int?,
  todayCalls: json['today_calls'] as int?,
  kycRejectionReason: json['kyc_rejection_reason'] as String?,
  level: json['level'] as int?,
  verificationStatus: json['verification_status'] as String? ?? 'not_applied',
  verificationNote: json['verification_note'] as String?,
  levelMaxRatePerMinute: json['level_max_rate_per_minute'] as int?,
  nextLevelMaxRatePerMinute: json['next_level_max_rate_per_minute'] as int?,
  verifiedRateThreshold: json['verified_rate_threshold'] as int? ?? 3000,
  onlineSessionId: (json['online_session'] as JsonMap?)?['id'] as String?,
  onlineSince: switch ((json['online_session'] as JsonMap?)?['started_at']) {
    final String at => DateTime.parse(at).toUtc(),
    _ => null,
  },
);
