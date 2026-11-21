import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/report_receipt.dart';

/// Maps the API's snake_case JSON to [ReportReceipt]. Keep in sync with api/openapi/dashuri.v1.yaml.
ReportReceipt reportReceiptFromJson(JsonMap json) => ReportReceipt(
  reportId: json['report_id']! as String,
  status: json['status']! as String,
);
