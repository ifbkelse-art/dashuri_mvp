import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/data/datasources/account_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  setUp(() async => api = await FakeApi.start());
  tearDown(() => api.close());

  test('GET /v1/me maps the MVP onboarding fields', () async {
    api.response = {
      'user_id': 'u1',
      'age_eligible': true,
      'is_host': true,
      'restriction': null,
      'profile_complete': true,
      'rules_accepted': false,
      'host_state': 'approved',
    };
    final result = await AccountRemoteDataSource(api.client).getAccountStatus();
    final status = (result as Success<AccountStatus>).value;
    expect(api.last.method, 'GET');
    expect(api.last.uri.path, '/v1/me');
    expect(api.last.headers.value('authorization'), 'Bearer test-token');
    expect(status.profileComplete, isTrue);
    expect(status.rulesAccepted, isFalse);
    expect(status.isApprovedHost, isTrue);
  });

  test('missing onboarding flags default to not done', () async {
    api.response = {'user_id': 'u1', 'age_eligible': true, 'is_host': false};
    final result = await AccountRemoteDataSource(api.client).getAccountStatus();
    final status = (result as Success<AccountStatus>).value;
    expect(status.profileComplete, isFalse);
    expect(status.rulesAccepted, isFalse);
    expect(status.hostState, isNull);
  });

  test('POST /v1/me/rules-acceptance sends the version', () async {
    api.response = {
      'user_id': 'u1',
      'age_eligible': true,
      'is_host': false,
      'rules_accepted': true,
    };
    final result = await AccountRemoteDataSource(
      api.client,
    ).acceptCommunityRules('2026-11');
    expect(result.isSuccess, isTrue);
    expect(api.last.method, 'POST');
    expect(api.last.uri.path, '/v1/me/rules-acceptance');
    expect(api.last.body, {'version': '2026-11'});
  });

  test('server errors become failures', () async {
    api
      ..status = 503
      ..response = {'code': 'database_unavailable'};
    final result = await AccountRemoteDataSource(api.client).getAccountStatus();
    expect((result as Err).failure, isA<ServerFailure>());
  });
}
