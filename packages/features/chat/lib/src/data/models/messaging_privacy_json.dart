import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/messaging_privacy.dart';

/// Maps the API's snake_case JSON to [MessagingPrivacy]. Keep in sync with api/openapi/dashuri.v1.yaml.
MessagingPrivacy messagingPrivacyFromJson(JsonMap json) =>
    MessagingPrivacy(whoCanMessage: json['who_can_message']! as String);
