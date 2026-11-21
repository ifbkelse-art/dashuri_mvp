import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_safety/feature_safety.dart';
import 'package:feature_safety/src/data/datasources/safety_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  setUp(() async => api = await FakeApi.start());
  tearDown(() => api.close());

  test('POST /v1/reports with category, call and idempotency key', () async {
    final key = IdempotencyKey.generate();
    api
      ..status = 201
      ..response = {'report_id': 'r1', 'status': 'open'};
    final r = await SafetyRemoteDataSource(api.client).reportUser(
      targetUserId: 'u2',
      category: 'minor_safety',
      callId: 'c1',
      details: null,
      idempotencyKey: key,
    );
    expect((r as Success<ReportReceipt>).value.reportId, 'r1');
    expect(api.last.uri.path, '/v1/reports');
    expect(api.last.headers.value('idempotency-key'), key.value);
    expect(api.last.body, {
      'target_user_id': 'u2',
      'category': 'minor_safety',
      'call_id': 'c1',
    });
  });

  test('GET /v1/blocks pages and DELETE /v1/blocks/{id}', () async {
    api.response = {
      'items': [
        {
          'user_id': 'b1',
          'display_name': 'Tara',
          'blocked_at': '2026-11-12T10:00:00Z',
        },
      ],
      'next_cursor': 'n2',
    };
    final ds = SafetyRemoteDataSource(api.client);
    final page = await ds.listBlockedUsers(
      page: const PageRequest(cursor: 'n1'),
    );
    expect((page as Success<Page<BlockedUser>>).value.nextCursor, 'n2');
    expect(api.last.uri.queryParameters, {'limit': '20', 'cursor': 'n1'});
    api
      ..status = 204
      ..response = null;
    expect((await ds.unblockUser(userId: 'b1')).isSuccess, isTrue);
    expect(api.last.method, 'DELETE');
    expect(api.last.uri.path, '/v1/blocks/b1');
  });

  test('age declaration and appeals', () async {
    final ds = SafetyRemoteDataSource(api.client);
    api.response = {'eligible': true, 'method': 'self_declared'};
    final age = await ds.submitAgeDeclaration(
      dateOfBirth: '1998-04-14',
      idempotencyKey: IdempotencyKey.generate(),
    );
    expect((age as Success<AgeStatus>).value.eligible, isTrue);
    expect(api.last.body, {'date_of_birth': '1998-04-14'});
    api
      ..status = 201
      ..response = {'appeal_id': 'a1', 'status': 'pending'};
    final appeal = await ds.submitAppeal(
      enforcementId: 'e1',
      statement: 'It was a mistake',
      idempotencyKey: IdempotencyKey.generate(),
    );
    expect(appeal.isSuccess, isTrue);
    expect(api.last.uri.path, '/v1/appeals');
  });
}
