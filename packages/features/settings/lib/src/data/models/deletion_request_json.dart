import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/deletion_request.dart';

/// Maps the API's snake_case JSON to [DeletionRequest]. Keep in sync with api/openapi/dashuri.v1.yaml.
DeletionRequest deletionRequestFromJson(JsonMap json) => DeletionRequest(
  requestId: json['request_id']! as String,
  status: json['status']! as String,
  scheduledFor: json['scheduled_for'] == null
      ? null
      : DateTime.parse(json['scheduled_for']! as String),
);
