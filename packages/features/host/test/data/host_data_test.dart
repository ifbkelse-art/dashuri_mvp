import 'dart:convert';
import 'dart:io';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_host/feature_host.dart';
// Data sources are package-private; tests reach them through src/.
// ignore: implementation_imports
import 'package:feature_host/src/data/datasources/host_profile_remote_data_source.dart';
// ignore: implementation_imports
import 'package:feature_host/src/data/datasources/host_remote_data_source.dart';
// ignore: implementation_imports
import 'package:feature_host/src/data/datasources/photo_upload_data_source.dart';
// ignore: implementation_imports
import 'package:feature_host/src/data/models/host_call_json.dart';
// ignore: implementation_imports
import 'package:feature_host/src/data/models/host_profile_json.dart';
// ignore: implementation_imports
import 'package:feature_host/src/data/models/host_status_json.dart';
// ignore: implementation_imports
import 'package:feature_host/src/data/repositories/host_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final class _Tokens implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => 'token-1';
}

typedef _Recorded = ({
  String method,
  String path,
  Map<String, String> query,
  Map<String, String> headers,
  List<int> body,
});

/// Minimal fake Go API on loopback.
final class _FakeServer {
  late HttpServer _server;
  final requests = <_Recorded>[];
  final routes = <String, (int, Object?)>{};

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      final body = await req.fold<List<int>>([], (a, b) => a..addAll(b));
      final headers = <String, String>{};
      req.headers.forEach((k, v) => headers[k] = v.join(','));
      requests.add((
        method: req.method,
        path: req.uri.path,
        query: req.uri.queryParameters,
        headers: headers,
        body: body,
      ));
      final (status, json) =
          routes['${req.method} ${req.uri.path}'] ??
          (404, {'code': 'not_found'});
      req.response.statusCode = status;
      if (json != null) {
        req.response.headers.contentType = status >= 400
            ? ContentType('application', 'problem+json')
            : ContentType.json;
        req.response.write(jsonEncode(json));
      }
      await req.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);

  Map<String, Object?> jsonBody(int i) =>
      jsonDecode(utf8.decode(requests[i].body)) as Map<String, Object?>;
}

const _statusJson = {
  'state': 'approved',
  'kyc_state': 'approved',
  'is_available': true,
  'rate_per_minute': 2400,
  'min_rate_per_minute': 500,
  'max_rate_per_minute': 4000,
  'free_call_opt_in': true,
  'today_earned_beans': 69106,
  'today_calls': 6,
};

const _profileJson = {
  'user_id': '11111111-1111-1111-1111-111111111111',
  'display_name': 'Ananya',
  'bio': null,
  'languages': ['hi'],
  'photo_urls': ['https://cdn.example/p1.jpg'],
  'is_host': true,
  'level': 4,
};

void main() {
  group('models', () {
    test('HostStatus parses MVP additions and tolerates their absence', () {
      final s = hostStatusFromJson(_statusJson);
      expect(s.todayEarnedBeans, 69106);
      expect(s.todayCalls, 6);
      expect(s.isApproved && s.isAvailable, isTrue);
      final minimal = hostStatusFromJson(
        {..._statusJson}..removeWhere((k, _) => k.startsWith('today_')),
      );
      expect(minimal.todayCalls, isNull);
      expect(minimal.kycRejectionReason, isNull);
    });

    test('Profile and update body', () {
      final p = hostProfileFromJson(_profileJson);
      expect(p.coverPhotoUrl, 'https://cdn.example/p1.jpg');
      expect(
        updateProfileToJson(displayName: ' A ', bio: ' ', languages: ['hi']),
        {
          'display_name': 'A',
          'bio': null,
          'languages': ['hi'],
        },
      );
    });

    test('call history row with and without optional fields', () {
      final full = hostCallFromJson({
        'call_id': 'c1',
        'role': 'receiver',
        'peer_user_id': 'u2',
        'peer': {'user_id': 'u2', 'display_name': 'Arjun', 'photo_url': null},
        'phase': 'ended',
        'rate_per_minute': 2400,
        'billed_seconds': 760,
        'diamonds_charged': 30400,
        'is_free_call': false,
        'started_at': '2026-11-21T15:28:00Z',
        'beans_earned': 18236,
      });
      expect(full.peerName, 'Arjun');
      expect(full.beansEarned, 18236);
      expect(full.isPaid, isTrue);
      final bare = hostCallFromJson({
        'call_id': 'c2',
        'role': 'receiver',
        'peer_user_id': 'u3',
        'phase': 'missed',
        'rate_per_minute': 2400,
        'billed_seconds': 0,
        'diamonds_charged': 0,
        'is_free_call': false,
      });
      expect(bare.peerName, isNull);
      expect(bare.startedAt, isNull);
      expect(bare.isMissed, isTrue);
    });

    test('Bean rules', () {
      expect(BeanRules.beansToPaise(124300), 62150);
      expect(sampleEarnings.balanceBeans, 210750);
      expect(sampleEarnings.canWithdraw, isTrue);
      expect(lowEarnings.canWithdraw, isFalse);
    });
  });

  group('remote data sources and repository', () {
    final server = _FakeServer();
    late HostRepositoryImpl repo;
    late HostRemoteDataSource remote;

    setUp(() async {
      await server.start();
      final api = ApiClient(baseUrl: server.baseUrl, tokens: _Tokens());
      remote = HostRemoteDataSource(api);
      repo = HostRepositoryImpl(
        remote,
        HostProfileRemoteDataSource(api),
        PhotoUploadDataSource(),
      );
    });
    tearDown(() async {
      server.requests.clear();
      server.routes.clear();
      await server.stop();
    });

    test('GET /v1/host 404 means not applied', () async {
      final r = await repo.getHostStatus();
      expect((r as Success<HostStatus>).value, HostStatus.notApplied);
      expect(server.requests.single.headers['authorization'], 'Bearer token-1');
    });

    test('availability, heartbeat, rate and opt-in bodies', () async {
      server.routes
        ..['PUT /v1/host/availability'] = (200, _statusJson)
        ..['POST /v1/host/availability/heartbeat'] = (204, null)
        ..['PUT /v1/host/rate'] = (200, _statusJson)
        ..['PUT /v1/host/free-call-opt-in'] = (200, _statusJson);
      expect((await repo.setAvailability(isAvailable: true)).isSuccess, isTrue);
      expect((await repo.sendHeartbeat()).isSuccess, isTrue);
      expect((await repo.setRate(ratePerMinute: 2400)).isSuccess, isTrue);
      expect((await repo.setFreeCallOptIn(optIn: false)).isSuccess, isTrue);
      expect(server.jsonBody(0), {'is_available': true});
      expect(server.jsonBody(2), {'rate_per_minute': 2400});
      expect(server.jsonBody(3), {'opt_in': false});
    });

    test('rate_outside_level_limits maps to a business rule failure', () async {
      server.routes['PUT /v1/host/rate'] = (
        409,
        {'code': 'business_rule', 'rule': 'rate_outside_level_limits'},
      );
      final r = await repo.setRate(ratePerMinute: 9000);
      expect(
        (r as Err).failure,
        const BusinessRuleFailure(code: 'rate_outside_level_limits'),
      );
    });

    test(
      'withdrawal sends the idempotency key; 503 payouts_not_enabled',
      () async {
        server.routes['POST /v1/host/withdrawals'] = (
          503,
          {'code': 'payouts_not_enabled', 'detail': 'disabled'},
        );
        final key = IdempotencyKey.generate();
        final r = await repo.requestWithdrawal(
          beans: 100000,
          idempotencyKey: key,
        );
        expect((r as Err).failure.code, 'payouts_not_enabled');
        expect(server.requests.single.headers['idempotency-key'], key.value);
        expect(server.jsonBody(0), {'beans': 100000});
      },
    );

    test('earnings and withdrawals page', () async {
      server.routes
        ..['GET /v1/host/earnings'] = (
          200,
          {
            'beans_on_hold': 86450,
            'beans_available': 124300,
            'beans_pending_payout': 0,
            'available_inr_paise': 62150,
            'next_payout_date': null,
          },
        )
        ..['GET /v1/host/withdrawals'] = (
          200,
          {
            'items': [
              {
                'id': 'w1',
                'beans': 124300,
                'amount_paise': 62150,
                'status': 'requested',
                'requested_at': '2026-11-21T10:00:00Z',
              },
            ],
            'next_cursor': 'n1',
          },
        );
      final e = await repo.getEarnings();
      expect((e as Success<HostEarnings>).value.availableInrPaise, 62150);
      final w = await repo.listWithdrawals(page: const PageRequest(limit: 10));
      final page = (w as Success<Page<Withdrawal>>).value;
      expect(page.items.single.status, WithdrawalStatuses.requested);
      expect(page.nextCursor, 'n1');
      expect(server.requests.last.query['limit'], '10');
    });

    test('apply and KYC session', () async {
      server.routes
        ..['POST /v1/host/application'] = (
          200,
          {..._statusJson, 'state': 'applied'},
        )
        ..['POST /v1/host/kyc/sessions'] = (201, {'session_id': 'kyc_1'});
      final a = await repo.applyAsHost(
        idempotencyKey: IdempotencyKey.generate(),
      );
      expect((a as Success<HostStatus>).value.state, 'applied');
      final k = await repo.startKyc(idempotencyKey: IdempotencyKey.generate());
      expect((k as Success<KycSession>).value.sessionId, 'kyc_1');
      expect(
        server.requests.every((r) => r.headers.containsKey('idempotency-key')),
        isTrue,
      );
    });

    test(
      'profile, call history and photo upload (ticket + PUT bytes)',
      () async {
        server.routes
          ..['GET /v1/me/profile'] = (200, _profileJson)
          ..['PATCH /v1/me/profile'] = (200, _profileJson)
          ..['GET /v1/calls/history'] = (
            200,
            {'items': <Object>[], 'next_cursor': null},
          )
          ..['PUT /storage/upload'] = (200, {'ok': true});
        server.routes['POST /v1/me/photos/upload-tickets'] = (
          201,
          {
            'photo_id': 'p1',
            'upload_url': '${server.baseUrl}/storage/upload?token=t',
            'expires_at': '2026-11-21T11:00:00Z',
          },
        );
        expect((await repo.getMyProfile()).isSuccess, isTrue);
        await repo.updateMyProfile(
          displayName: 'Ananya',
          bio: 'Hi',
          languages: ['hi'],
        );
        expect(server.jsonBody(1), {
          'display_name': 'Ananya',
          'bio': 'Hi',
          'languages': ['hi'],
        });
        expect(
          (await repo.listCallHistory(page: const PageRequest())).isSuccess,
          isTrue,
        );

        final r = await repo.uploadPhoto(
          photo: samplePhoto,
          idempotencyKey: IdempotencyKey.generate(),
        );
        expect((r as Success<PhotoUploadTicket>).value.photoId, 'p1');
        final ticketReq = server.requests[3];
        expect(server.jsonBody(3), {'content_type': 'image/jpeg'});
        expect(ticketReq.path, '/v1/me/photos/upload-tickets');
        final put = server.requests[4];
        expect(put.method, 'PUT');
        expect(put.query['token'], 't');
        expect(put.body, [1, 2, 3]);
        expect(put.headers['content-type'], startsWith('image/jpeg'));
        expect(put.headers.containsKey('authorization'), isFalse);
      },
    );

    test('photo upload reports a failed PUT', () async {
      final r = await PhotoUploadDataSource().upload(
        ticket: PhotoUploadTicket(
          photoId: 'p1',
          uploadUrl: Uri.parse('${server.baseUrl}/missing'),
          expiresAt: DateTime.utc(2026),
        ),
        photo: samplePhoto,
      );
      expect((r as Err).failure.code, 'photo_upload_failed');
    });

    test('photo upload with no server is a network failure', () async {
      final r = await PhotoUploadDataSource().upload(
        ticket: PhotoUploadTicket(
          photoId: 'p1',
          uploadUrl: Uri.parse('http://127.0.0.1:1/x'),
          expiresAt: DateTime.utc(2026),
        ),
        photo: samplePhoto,
      );
      expect((r as Err).failure, isA<NetworkFailure>());
    });
  });

  test('UploadHostPhoto rejects unsupported content types', () async {
    final repo = MockHostRepository();
    final r = await UploadHostPhoto(repo)((
      photo: PickedPhoto(bytes: samplePhoto.bytes, contentType: 'image/gif'),
      idempotencyKey: IdempotencyKey.generate(),
    ));
    expect((r as Err).failure, isA<ValidationFailure>());
  });
}
