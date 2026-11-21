import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/photo_upload_ticket.dart';

/// Maps the API's snake_case JSON to [PhotoUploadTicket]. Keep in sync with api/openapi/dashuri.v1.yaml.
PhotoUploadTicket photoUploadTicketFromJson(JsonMap json) => PhotoUploadTicket(
  photoId: json['photo_id']! as String,
  uploadUrl: json['upload_url']! as String,
  expiresAt: DateTime.parse(json['expires_at']! as String),
);
