import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/account_status.dart';
import '../models/account_status_json.dart';

final class AccountRemoteDataSource {
  const AccountRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<AccountStatus>> getAccountStatus() =>
      _api.get('/v1/me', decode: objectDecoder(accountStatusFromJson));

  Future<Result<AccountStatus>> acceptCommunityRules(String version) =>
      _api.post(
        '/v1/me/rules-acceptance',
        decode: objectDecoder(accountStatusFromJson),
        body: {'version': version},
      );
}
