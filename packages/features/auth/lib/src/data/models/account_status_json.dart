import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/account_status.dart';

AccountStatus accountStatusFromJson(JsonMap json) => AccountStatus(
  userId: json['user_id']! as String,
  ageEligible: json['age_eligible']! as bool,
  isHost: json['is_host']! as bool,
  restriction: json['restriction'] as String?,
);
