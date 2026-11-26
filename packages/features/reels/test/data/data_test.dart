import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:feature_reels/src/data/datasources/reels_remote_data_source.dart';
import 'package:feature_reels/src/data/models/reels_json.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

const _reel = {
  'id': 'r1',
  'creator': {
    'user_id': 'u1',
    'display_name': 'Asha',
    'photo_url': null,
    'followed_by_me': true,
    'host': {
      'availability': 'busy',
      'rate_per_minute': 1500,
      'is_verified': true,
    },
  },
  'caption': 'hi',
  'language': 'hi',
  'duration_ms': 21000,
  'status': 'published',
  'rejection_code': null,
  'like_count': 4,
  'view_count': 9,
  'share_count': 1,
  'liked_by_me': false,
  'is_mine': false,
  'playback': {
    'hls_url': 'https://stream/x.m3u8',
    'thumbnail_url': 'https://img/x.jpg',
    'expires_at': '2026-11-22T18:00:00Z',
  },
  'published_at': '2026-11-22T10:00:00Z',
  'created_at': '2026-11-22T09:59:00Z',
};

void main() {
  test('reelFromJson maps creator, host, playback and status', () {
    final r = reelFromJson(_reel);
    expect(r.creator.host!.availability, 'busy');
    expect(r.creator.followedByMe, isTrue);
    // Legacy (pre-R2) server: only hls_url → HLS.
    expect(r.playback!.url, 'https://stream/x.m3u8');
    expect(r.playback!.format, ReelMediaFormat.hls);
    final r2 = reelFromJson({
      ..._reel,
      'playback': {
        'url':
            'https://acct.r2.cloudflarestorage.com/media/reels/x/playback.mp4?X-Amz-Signature=s',
        'format': 'mp4',
        'hls_url': '',
        'thumbnail_url': 'https://img/x.jpg',
        'expires_at': '2026-11-22T18:00:00Z',
      },
    });
    expect(r2.playback!.format, ReelMediaFormat.mp4);
    expect(r2.playback!.url, endsWith('X-Amz-Signature=s'));
    expect(r.status, ReelStatus.published);
    final regular = reelFromJson({
      ..._reel,
      'creator': {...(_reel['creator']! as Map<String, Object?>), 'host': null},
      'playback': null,
      'status': 'in_review',
    });
    expect(regular.creator.host, isNull);
    expect(regular.playback, isNull);
    expect(regular.status, ReelStatus.inReview);
  });

  group('ReelsRemoteDataSource', () {
    late FakeApi api;
    late ReelsRemoteDataSource ds;
    setUp(() async {
      api = await FakeApi.start();
      ds = ReelsRemoteDataSource(api.client);
    });
    tearDown(() => api.close());

    test('feed sends tab, limit and cursor and decodes the page', () async {
      api.response = {
        'items': [_reel],
        'next_cursor': 'abc',
      };
      final res = await ds.feed(FeedTab.following, cursor: 'c1', limit: 10);
      expect(api.last.uri.path, '/v1/reels/feed');
      expect(api.last.uri.queryParameters, {
        'tab': 'following',
        'limit': '10',
        'cursor': 'c1',
      });
      final p = (res as Success<Page<Reel>>).value;
      expect(p.items.single.id, 'r1');
      expect(p.nextCursor, 'abc');
    });

    test('like and follow use PUT with an explicit state', () async {
      api.response = {'liked': false, 'like_count': 3};
      final like = await ds.setLike('r1', false);
      expect(api.last.method, 'PUT');
      expect(api.last.uri.path, '/v1/reels/r1/like');
      expect(api.last.body, {'liked': false});
      expect((like as Success).value, (liked: false, likeCount: 3));
      api.response = {'following': true};
      await ds.setFollow('u1', true);
      expect(api.last.uri.path, '/v1/creators/u1/follow');
      expect(api.last.body, {'following': true});
    });

    test('upload ticket and report carry an idempotency key', () async {
      api
        ..status = 201
        ..response = {
          'reel': {..._reel, 'status': 'awaiting_upload'},
          'upload_url': 'https://up/x',
          'upload_headers': {
            'Content-Type': 'video/mp4',
            'Content-Length': '5',
          },
          'expires_at': '2026-11-22T12:00:00Z',
        };
      final key = IdempotencyKey.generate();
      final t = await ds.createUpload(
        caption: 'c',
        durationMs: 20000,
        sizeBytes: 5,
        contentType: 'video/mp4',
        idempotencyKey: key,
      );
      expect(api.last.headers.value('idempotency-key'), key.value);
      expect(api.last.body, {
        'caption': 'c',
        'duration_ms': 20000,
        'size_bytes': 5,
        'content_type': 'video/mp4',
      });
      final ticket = (t as Success<ReelUploadTicket>).value;
      expect(ticket.uploadUrl, 'https://up/x');
      expect(ticket.uploadHeaders, {
        'Content-Type': 'video/mp4',
        'Content-Length': '5',
      });
      api
        ..status = 204
        ..response = null;
      final rep = await ds.report(
        'r1',
        ReelReportCategory.minorSafety,
        idempotencyKey: key,
      );
      expect(rep.isSuccess, isTrue);
      expect(api.last.body, {'category': 'minor_safety'});
    });

    test('events are batched in one POST without nulls', () async {
      api.status = 202;
      await ds.track(const [
        ReelEvent(name: ReelEventName.impression, reelId: 'r1', sessionId: 's'),
        ReelEvent(name: ReelEventName.hostCallCtaClicked, creatorId: 'u1'),
      ]);
      expect(api.last.body, {
        'events': [
          {'event': 'reel_impression', 'reel_id': 'r1', 'session_id': 's'},
          {'event': 'host_call_cta_clicked', 'creator_id': 'u1'},
        ],
      });
    });

    test('server problems map to failures (feature switched off)', () async {
      api
        ..status = 503
        ..response = {
          'type': 'about:blank',
          'title': 'Unavailable',
          'status': 503,
          'code': 'reels_disabled',
        };
      final res = await ds.config();
      expect((res as Err).failure.code, 'reels_disabled');
    });
  });
}
