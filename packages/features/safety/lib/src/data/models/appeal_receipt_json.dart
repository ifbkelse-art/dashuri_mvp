import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/appeal_receipt.dart';

/// Maps the API's snake_case JSON to [AppealReceipt]. Keep in sync with api/openapi/dashuri.v1.yaml.
AppealReceipt appealReceiptFromJson(JsonMap json) => AppealReceipt(
  appealId: json['appeal_id']! as String,
  status: json['status']! as String,
);
