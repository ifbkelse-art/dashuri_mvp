import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_earnings.dart';

/// Maps the API's snake_case JSON to [HostEarnings]. Keep in sync with api/openapi/dashuri.v1.yaml.
HostEarnings hostEarningsFromJson(JsonMap json) => HostEarnings(
  beansOnHold: json['beans_on_hold']! as int,
  beansAvailable: json['beans_available']! as int,
  beansPendingPayout: json['beans_pending_payout']! as int,
  availableInrPaise: json['available_inr_paise']! as int,
  nextPayoutDate: json['next_payout_date'] == null
      ? null
      : DateTime.parse(json['next_payout_date']! as String),
);
