import 'package:dashuri_core/dashuri_core.dart';

/// Play Integrity token for the Free Call Card (S4 device binding). The
/// Android side derives the request nonce natively; failures map to
/// `PlatformFailure(code: 'integrity_unavailable')`.
abstract interface class IntegrityTokenProvider {
  Future<Result<String>> requestToken();
}
