import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/wallet_entry.dart';

/// Maps the API's snake_case JSON to [WalletEntry]. Keep in sync with api/openapi/dashuri.v1.yaml.
WalletEntry walletEntryFromJson(JsonMap json) => WalletEntry(
  id: json['id']! as String,
  currency: json['currency']! as String,
  kind: json['kind']! as String,
  amount: json['amount']! as int,
  createdAt: DateTime.parse(json['created_at']! as String),
  reference: json['reference'] as String?,
);
