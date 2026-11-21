import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/inbox_item.dart';

/// Maps the API's snake_case JSON to [InboxItem]. Keep in sync with api/openapi/dashuri.v1.yaml.
InboxItem inboxItemFromJson(JsonMap json) => InboxItem(
  id: json['id']! as String,
  kind: json['kind']! as String,
  title: json['title']! as String,
  body: json['body']! as String,
  createdAt: DateTime.parse(json['created_at']! as String),
  readAt: json['read_at'] == null
      ? null
      : DateTime.parse(json['read_at']! as String),
);
