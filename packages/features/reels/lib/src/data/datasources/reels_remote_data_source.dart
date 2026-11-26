import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/creator_profile.dart';
import '../../domain/entities/reel.dart';
import '../../domain/repositories/reels_repository.dart';
import '../models/reels_json.dart';

/// HTTP access to the Reels endpoints of the Go API.
final class ReelsRemoteDataSource implements ReelsRepository {
  const ReelsRemoteDataSource(this._api);

  final ApiClient _api;

  static String _e(String s) => Uri.encodeComponent(s);

  @override
  Future<Result<ReelsConfig>> config() =>
      _api.get('/v1/reels/config', decode: objectDecoder(reelsConfigFromJson));

  @override
  Future<Result<Page<Reel>>> feed(
    FeedTab tab, {
    String? cursor,
    int limit = 10,
  }) => _api.get(
    '/v1/reels/feed',
    decode: pageDecoder(reelFromJson),
    query: {'tab': tab.wire, 'limit': '$limit', 'cursor': ?cursor},
  );

  @override
  Future<Result<Reel>> reel(String id) =>
      _api.get('/v1/reels/${_e(id)}', decode: objectDecoder(reelFromJson));

  @override
  Future<Result<({bool liked, int likeCount})>> setLike(String id, bool like) =>
      _api.put(
        '/v1/reels/${_e(id)}/like',
        body: {'liked': like},
        decode: (json) {
          final m = json! as JsonMap;
          return (
            liked: m['liked']! as bool,
            likeCount: m['like_count']! as int,
          );
        },
      );

  @override
  Future<Result<bool>> setFollow(String creatorId, bool follow) => _api.put(
    '/v1/creators/${_e(creatorId)}/follow',
    body: {'following': follow},
    decode: (json) => (json! as JsonMap)['following']! as bool,
  );

  @override
  Future<Result<String>> share(String id) => _api.post(
    '/v1/reels/${_e(id)}/share',
    decode: (json) => (json! as JsonMap)['text']! as String,
  );

  @override
  Future<Result<void>> report(
    String id,
    ReelReportCategory category, {
    String? details,
    required IdempotencyKey idempotencyKey,
  }) => _api.post<void>(
    '/v1/reels/${_e(id)}/reports',
    decode: (_) {},
    body: {'category': category.wire, 'details': ?details},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<void>> appeal(
    String id,
    String statement, {
    required IdempotencyKey idempotencyKey,
  }) => _api.post<void>(
    '/v1/reels/${_e(id)}/appeals',
    decode: (_) {},
    body: {'statement': statement},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<void>> delete(String id) => _api.delete('/v1/reels/${_e(id)}');

  @override
  Future<Result<CreatorProfile>> creator(String userId) => _api.get(
    '/v1/creators/${_e(userId)}',
    decode: objectDecoder(creatorProfileFromJson),
  );

  @override
  Future<Result<Page<Reel>>> creatorReels(
    String userId, {
    String? cursor,
    int limit = 18,
  }) => _api.get(
    '/v1/creators/${_e(userId)}/reels',
    decode: pageDecoder(reelFromJson),
    query: {'limit': '$limit', 'cursor': ?cursor},
  );

  @override
  Future<Result<ReelUploadTicket>> createUpload({
    required String caption,
    required int durationMs,
    required int sizeBytes,
    required String contentType,
    String? language,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/reels/uploads',
    decode: objectDecoder(
      (j) => ReelUploadTicket(
        reel: reelFromJson(j['reel']! as JsonMap),
        uploadUrl: j['upload_url']! as String,
        uploadHeaders: {
          for (final e
              in ((j['upload_headers'] as JsonMap?) ?? const {}).entries)
            e.key: e.value! as String,
        },
      ),
    ),
    body: {
      'caption': caption,
      'duration_ms': durationMs,
      'size_bytes': sizeBytes,
      'content_type': contentType,
      'language': ?language,
    },
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<void>> uploadBytes({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
    Map<String, String> headers = const {},
    void Function(double fraction)? onProgress,
  }) => _api.uploadToSignedUrl(
    Uri.parse(uploadUrl),
    bytes,
    contentType: contentType,
    headers: headers,
    onProgress: onProgress,
  );

  @override
  Future<Result<Reel>> completeUpload(String id) => _api.post(
    '/v1/reels/${_e(id)}/upload-complete',
    decode: objectDecoder(reelFromJson),
  );

  @override
  Future<Result<void>> track(List<ReelEvent> events) => _api.post<void>(
    '/v1/reels/events',
    decode: (_) {},
    body: {'events': events.map(eventToJson).toList()},
  );
}
