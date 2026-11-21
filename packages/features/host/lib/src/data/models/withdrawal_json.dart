import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/withdrawal.dart';

/// Maps the API's snake_case JSON to [Withdrawal]. Keep in sync with api/openapi/dashuri.v1.yaml.
Withdrawal withdrawalFromJson(JsonMap json) => Withdrawal(
  id: json['id']! as String,
  beans: json['beans']! as int,
  amountPaise: json['amount_paise']! as int,
  status: json['status']! as String,
  requestedAt: DateTime.parse(json['requested_at']! as String),
  paidAt: json['paid_at'] == null
      ? null
      : DateTime.parse(json['paid_at']! as String),
);
