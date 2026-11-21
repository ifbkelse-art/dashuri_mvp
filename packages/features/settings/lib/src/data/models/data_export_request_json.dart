import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/data_export_request.dart';

/// Maps the API's snake_case JSON to [DataExportRequest]. Keep in sync with api/openapi/dashuri.v1.yaml.
DataExportRequest dataExportRequestFromJson(JsonMap json) => DataExportRequest(
  requestId: json['request_id']! as String,
  status: json['status']! as String,
);
