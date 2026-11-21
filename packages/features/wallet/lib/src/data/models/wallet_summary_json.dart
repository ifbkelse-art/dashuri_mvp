import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/wallet_summary.dart';

/// Maps the API's snake_case JSON to [WalletSummary]. Keep in sync with api/openapi/dashuri.v1.yaml.
WalletSummary walletSummaryFromJson(JsonMap json) => WalletSummary(
  purchasedDiamonds: json['purchased_diamonds']! as int,
  promotionalDiamonds: json['promotional_diamonds']! as int,
  reservedDiamonds: json['reserved_diamonds']! as int,
  availableDiamonds: json['available_diamonds']! as int,
  beansOnHold: json['beans_on_hold']! as int,
  beansAvailable: json['beans_available']! as int,
  beansPendingPayout: json['beans_pending_payout']! as int,
);
