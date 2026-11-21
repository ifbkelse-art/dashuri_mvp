import 'package:dashuri_core/dashuri_core.dart';

import '../ports/integrity_token_provider.dart';

/// Requests a Play Integrity token from the platform.
// Not final: application tests mock use cases.
class GetIntegrityToken implements UseCase<String, NoInput> {
  const GetIntegrityToken(this._provider);

  final IntegrityTokenProvider _provider;

  @override
  Future<Result<String>> call(NoInput input) => _provider.requestToken();
}
