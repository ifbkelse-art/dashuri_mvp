import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/kyc_session.dart';

/// Maps the API's snake_case JSON to [KycSession]. Keep in sync with api/openapi/dashuri.v1.yaml.
KycSession kycSessionFromJson(JsonMap json) => KycSession(
  sessionId: json['session_id']! as String,
  redirectUrl: json['redirect_url'] as String?,
);
