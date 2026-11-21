import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_settings/src/data/datasources/settings_remote_data_source.dart';
import 'package:feature_settings/src/data/repositories/settings_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_api.dart';
import '../helpers/mocks.dart';

void main() {
  late FakeApi api;
  late MockSessionGateway session;
  late SettingsRepositoryImpl repo;

  setUp(() async {
    api = await FakeApi.start();
    session = MockSessionGateway();
    repo = SettingsRepositoryImpl(
      SettingsRemoteDataSource(api.client),
      session,
    );
  });
  tearDown(() => api.close());

  test('messaging privacy GET/PUT', () async {
    api.response = {'who_can_message': 'past_call_partners'};
    final got = await repo.getMessagingPrivacy();
    expect(
      (got as Success<WhoCanMessage>).value,
      WhoCanMessage.pastCallPartners,
    );
    api.response = {'who_can_message': 'everyone'};
    await repo.setMessagingPrivacy(WhoCanMessage.everyone);
    expect(api.last.method, 'PUT');
    expect(api.last.uri.path, '/v1/me/messaging-privacy');
    expect(api.last.body, {'who_can_message': 'everyone'});
  });

  test('consents PUT sends both flags', () async {
    api.response = {
      'analytics': true,
      'marketing': false,
      'updated_at': '2026-11-21T10:00:00Z',
    };
    final r = await repo.updateConsents(analytics: true, marketing: false);
    expect((r as Success<ConsentState>).value.analytics, isTrue);
    expect(api.last.body, {'analytics': true, 'marketing': false});
  });

  test(
    'grievance posts a report of category other about the reporter',
    () async {
      when(
        () => session.currentSession,
      ).thenReturn(AuthSession(userId: 'me', expiresAt: DateTime.utc(2030)));
      final key = IdempotencyKey.generate();
      api
        ..status = 201
        ..response = {'report_id': 'r9', 'status': 'open'};
      final r = await repo.submitGrievance(
        details: 'Refund missing',
        idempotencyKey: key,
      );
      expect((r as Success<String>).value, 'r9');
      expect(api.last.uri.path, '/v1/reports');
      expect(api.last.headers.value('idempotency-key'), key.value);
      expect(api.last.body, {
        'target_user_id': 'me',
        'category': 'other',
        'details': 'Grievance: Refund missing',
      });
    },
  );

  test('grievance without a session fails without a request', () async {
    when(() => session.currentSession).thenReturn(null);
    final r = await repo.submitGrievance(
      details: 'x',
      idempotencyKey: IdempotencyKey.generate(),
    );
    expect((r as Err).failure, isA<UnauthenticatedFailure>());
    expect(api.requests, isEmpty);
  });

  test(
    'deletion 409 pending_balance_or_payout maps to a business rule',
    () async {
      api
        ..status = 409
        ..response = {
          'code': 'business_rule',
          'rule': 'pending_balance_or_payout',
        };
      final r = await repo.requestAccountDeletion(
        idempotencyKey: IdempotencyKey.generate(),
      );
      expect((r as Err).failure.code, 'pending_balance_or_payout');
      expect(api.last.uri.path, '/v1/me/deletion-requests');
    },
  );

  test('deletion accepted and data export', () async {
    api
      ..status = 202
      ..response = {
        'request_id': 'd1',
        'status': 'scheduled',
        'scheduled_for': '2026-11-28T00:00:00Z',
      };
    final d = await repo.requestAccountDeletion(
      idempotencyKey: IdempotencyKey.generate(),
    );
    expect(
      (d as Success<DeletionRequest>).value.scheduledFor,
      DateTime.utc(2026, 11, 28),
    );
    api.response = {'request_id': 'x1', 'status': 'queued'};
    final e = await repo.requestDataExport(
      idempotencyKey: IdempotencyKey.generate(),
    );
    expect(e.isSuccess, isTrue);
    expect(api.last.uri.path, '/v1/me/data-exports');
  });

  test('signOut goes through the session gateway', () async {
    when(session.signOut).thenAnswer((_) async => const Success<void>(null));
    expect((await repo.signOut()).isSuccess, isTrue);
    verify(session.signOut).called(1);
  });
}
