import 'package:dashuri_core/dashuri_core.dart';

import '../entities/creator_profile.dart';
import '../entities/reel.dart';

/// Upload ticket: the created reel (awaiting_upload) and a one-time URL.
final class ReelUploadTicket {
  const ReelUploadTicket({
    required this.reel,
    required this.uploadUrl,
    this.uploadHeaders = const {},
  });

  final Reel reel;
  final String uploadUrl;

  /// Sent unchanged with the PUT (R2 signs Content-Type and Content-Length
  /// into the URL, so a different file is refused). Empty for Mux.
  final Map<String, String> uploadHeaders;
}

/// Reels API contract (docs/reels/DASHURI_REELS_DATABASE_AND_API.md).
abstract interface class ReelsRepository {
  Future<Result<ReelsConfig>> config();

  Future<Result<Page<Reel>>> feed(FeedTab tab, {String? cursor, int limit});

  Future<Result<Reel>> reel(String id);

  Future<Result<({bool liked, int likeCount})>> setLike(String id, bool like);

  Future<Result<bool>> setFollow(String creatorId, bool follow);

  /// Returns the share text (with link) to copy.
  Future<Result<String>> share(String id);

  Future<Result<void>> report(
    String id,
    ReelReportCategory category, {
    String? details,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<void>> appeal(
    String id,
    String statement, {
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<void>> delete(String id);

  Future<Result<CreatorProfile>> creator(String userId);

  Future<Result<Page<Reel>>> creatorReels(
    String userId, {
    String? cursor,
    int limit,
  });

  /// [sizeBytes] and [contentType] describe the file; the server signs them
  /// into the R2 upload URL.
  Future<Result<ReelUploadTicket>> createUpload({
    required String caption,
    required int durationMs,
    required int sizeBytes,
    required String contentType,
    String? language,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<void>> uploadBytes({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
    Map<String, String> headers = const {},
    void Function(double fraction)? onProgress,
  });

  /// Tells the server the PUT finished; it checks the storage itself.
  Future<Result<Reel>> completeUpload(String id);

  Future<Result<void>> track(List<ReelEvent> events);
}
