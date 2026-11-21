import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:feature_profile/src/data/datasources/profile_remote_data_source.dart';
import 'package:feature_profile/src/data/models/profile_json.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

const _json = {
  'user_id': 'u1',
  'display_name': 'Arjun',
  'bio': null,
  'languages': ['hi'],
  'photo_urls': ['https://x/p.jpg'],
  'is_host': false,
  'level': 3,
  'gender': 'non_binary',
  'city': {'id': 'pune', 'name': 'Pune', 'state': 'Maharashtra'},
};

void main() {
  test('profileFromJson maps gender and city', () {
    final p = profileFromJson(_json);
    expect(p.gender, Gender.nonBinary);
    expect(
      p.city,
      const ProfileCity(id: 'pune', name: 'Pune', state: 'Maharashtra'),
    );
    expect(p.photoUrl, 'https://x/p.jpg');
    expect(
      profileFromJson({..._json, 'gender': null, 'city': null}).city,
      isNull,
    );
  });

  test(
    'profileUpdateToJson sends only changed fields; clearCity sends null',
    () {
      expect(
        profileUpdateToJson(
          const ProfileUpdate(displayName: 'A', gender: Gender.woman),
        ),
        {'display_name': 'A', 'gender': 'woman'},
      );
      expect(profileUpdateToJson(const ProfileUpdate(clearCity: true)), {
        'city_id': null,
      });
    },
  );

  group('ProfileRemoteDataSource', () {
    late FakeApi api;
    setUp(() async => api = await FakeApi.start());
    tearDown(() => api.close());

    test('PATCH /v1/me/profile', () async {
      api.response = _json;
      final r = await ProfileRemoteDataSource(api.client).updateMyProfile(
        const ProfileUpdate(displayName: 'Arjun', languages: ['hi']),
      );
      expect(r.isSuccess, isTrue);
      expect(api.last.method, 'PATCH');
      expect(api.last.uri.path, '/v1/me/profile');
      expect(api.last.body, {
        'display_name': 'Arjun',
        'languages': ['hi'],
      });
    });

    test('profile_text_rejected surfaces as a BusinessRuleFailure', () async {
      api
        ..status = 409
        ..response = {'code': 'business_rule', 'rule': 'profile_text_rejected'};
      final r = await ProfileRemoteDataSource(
        api.client,
      ).updateMyProfile(const ProfileUpdate(displayName: 'call 9876543210'));
      final failure = (r as Err).failure;
      expect(failure.code, 'profile_text_rejected');
      expect(rejectedProfileField(failure), 'any');
    });

    test('GET /v1/me/level and /v1/wallet', () async {
      api.response = {
        'level': 2,
        'lifetime_xp': 10,
        'current_level_xp': 0,
        'next_level_xp': 50,
      };
      final level = await ProfileRemoteDataSource(api.client).getMyLevel();
      expect((level as Success<LevelProgress>).value.nextLevelXp, 50);
      api.response = {
        'purchased_diamonds': 1,
        'promotional_diamonds': 0,
        'reserved_diamonds': 0,
        'available_diamonds': 12480,
        'beans_on_hold': 0,
        'beans_available': 0,
        'beans_pending_payout': 0,
      };
      final d = await ProfileRemoteDataSource(
        api.client,
      ).getAvailableDiamonds();
      expect((d as Success<int>).value, 12480);
      expect(api.last.uri.path, '/v1/wallet');
    });

    test('photo upload: ticket with idempotency key, then PUT bytes', () async {
      final key = IdempotencyKey.generate();
      api
        ..status = 201
        ..response = {
          'photo_id': 'p1',
          'upload_url': 'http://placeholder',
          'expires_at': '2026-11-21T10:00:00Z',
        };
      final ds = ProfileRemoteDataSource(api.client);
      final ticket = await ds.requestPhotoUpload(
        contentType: 'image/jpeg',
        idempotencyKey: key,
      );
      expect(api.last.headers.value('idempotency-key'), key.value);
      expect(api.last.body, {'content_type': 'image/jpeg'});
      expect(ticket.isSuccess, isTrue);

      api
        ..status = 200
        ..response = null;
      final put = await ds.uploadBytes(
        uploadUrl: 'http://127.0.0.1:${api.port}/storage/p1',
        bytes: [1, 2, 3],
        contentType: 'image/jpeg',
      );
      expect(put.isSuccess, isTrue);
      expect(api.last.method, 'PUT');
      expect(api.last.uri.path, '/storage/p1');
      expect(api.last.headers.value('authorization'), isNull);
      expect(api.last.headers.contentType?.mimeType, 'image/jpeg');
    });
  });
}
