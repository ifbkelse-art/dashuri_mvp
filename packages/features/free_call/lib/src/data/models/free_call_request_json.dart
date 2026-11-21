import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/free_call_request.dart';

/// Maps the API's snake_case JSON to [FreeCallRequest]. Keep in sync with api/openapi/dashuri.v1.yaml.
FreeCallRequest freeCallRequestFromJson(JsonMap json) => FreeCallRequest(
  requestId: json['request_id']! as String,
  status: json['status']! as String,
  callId: json['call_id'] as String?,
);
