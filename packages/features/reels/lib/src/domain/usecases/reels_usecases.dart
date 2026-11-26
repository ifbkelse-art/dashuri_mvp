import 'package:dashuri_core/dashuri_core.dart';

import '../entities/creator_profile.dart';
import '../entities/reel.dart';
import '../ports/reel_video_picker.dart';
import '../repositories/reels_repository.dart';

// Use cases are small and stateless; not final so application tests can mock them.

class GetReelsConfig implements UseCase<ReelsConfig, NoInput> {
  const GetReelsConfig(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<ReelsConfig>> call(NoInput _) => _r.config();
}

class GetReelsFeed
    implements UseCase<Page<Reel>, ({FeedTab tab, String? cursor})> {
  const GetReelsFeed(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<Page<Reel>>> call(({FeedTab tab, String? cursor}) i) =>
      _r.feed(i.tab, cursor: i.cursor, limit: 10);
}

class SetReelLike
    implements
        UseCase<({bool liked, int likeCount}), ({String id, bool like})> {
  const SetReelLike(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<({bool liked, int likeCount})>> call(
    ({String id, bool like}) i,
  ) => _r.setLike(i.id, i.like);
}

class SetCreatorFollow
    implements UseCase<bool, ({String creatorId, bool follow})> {
  const SetCreatorFollow(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<bool>> call(({String creatorId, bool follow}) i) =>
      _r.setFollow(i.creatorId, i.follow);
}

class ShareReel implements UseCase<String, String> {
  const ShareReel(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<String>> call(String id) => _r.share(id);
}

class ReportReel
    implements
        UseCase<
          void,
          ({String id, ReelReportCategory category, String? details})
        > {
  const ReportReel(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<void>> call(
    ({String id, ReelReportCategory category, String? details}) i,
  ) => _r.report(
    i.id,
    i.category,
    details: i.details,
    idempotencyKey: IdempotencyKey.generate(),
  );
}

class AppealReel implements UseCase<void, ({String id, String statement})> {
  const AppealReel(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<void>> call(({String id, String statement}) i) =>
      _r.appeal(i.id, i.statement, idempotencyKey: IdempotencyKey.generate());
}

class DeleteReel implements UseCase<void, String> {
  const DeleteReel(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<void>> call(String id) => _r.delete(id);
}

class GetReel implements UseCase<Reel, String> {
  const GetReel(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<Reel>> call(String id) => _r.reel(id);
}

class GetCreatorProfile implements UseCase<CreatorProfile, String> {
  const GetCreatorProfile(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<CreatorProfile>> call(String userId) => _r.creator(userId);
}

class GetCreatorReels
    implements UseCase<Page<Reel>, ({String userId, String? cursor})> {
  const GetCreatorReels(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<Page<Reel>>> call(({String userId, String? cursor}) i) =>
      _r.creatorReels(i.userId, cursor: i.cursor, limit: 18);
}

class TrackReelEvents implements UseCase<void, List<ReelEvent>> {
  const TrackReelEvents(this._r);
  final ReelsRepository _r;
  @override
  Future<Result<void>> call(List<ReelEvent> events) => _r.track(events);
}

/// Validation failure codes the upload page explains in plain language.
abstract final class ReelUploadRule {
  static const unreadableDuration = 'reel_duration_unreadable';
  static const tooShort = 'reel_too_short';
  static const tooLong = 'reel_too_long';
  static const tooLarge = 'reel_file_too_large';
}

/// Validates a picked video against the server's limits (R3 preview).
/// Returns the duration in ms, or a [ValidationFailure]-like business rule.
Result<int> validatePickedVideo(PickedVideo video, ReelsConfig config) {
  if (video.bytes.length > config.maxUploadBytes) {
    return const Err(BusinessRuleFailure(code: ReelUploadRule.tooLarge));
  }
  final ms = Mp4Duration.read(video.bytes);
  if (ms == null) {
    return const Err(
      BusinessRuleFailure(code: ReelUploadRule.unreadableDuration),
    );
  }
  // Same tolerance as the server (encoders round durations).
  if (ms < config.minDurationMs - 900) {
    return const Err(BusinessRuleFailure(code: ReelUploadRule.tooShort));
  }
  if (ms > config.maxDurationMs + 900) {
    return const Err(BusinessRuleFailure(code: ReelUploadRule.tooLong));
  }
  return Success(ms.clamp(config.minDurationMs, config.maxDurationMs));
}

/// POST /v1/reels/uploads, then PUT the file to the one-time URL. The reel
/// stays private (processing → moderation) until approved.
class UploadReel
    implements
        UseCase<
          Reel,
          ({
            PickedVideo video,
            int durationMs,
            String caption,
            String? language,
            IdempotencyKey idempotencyKey,
            void Function(double)? onProgress,
          })
        > {
  const UploadReel(this._r);
  final ReelsRepository _r;

  @override
  Future<Result<Reel>> call(
    ({
      PickedVideo video,
      int durationMs,
      String caption,
      String? language,
      IdempotencyKey idempotencyKey,
      void Function(double)? onProgress,
    })
    i,
  ) async {
    final ticket = await _r.createUpload(
      caption: i.caption,
      durationMs: i.durationMs,
      sizeBytes: i.video.bytes.length,
      contentType: i.video.contentType,
      language: i.language,
      idempotencyKey: i.idempotencyKey,
    );
    switch (ticket) {
      case Err(:final failure):
        return Err(failure);
      case Success(:final value):
        final up = await _r.uploadBytes(
          uploadUrl: value.uploadUrl,
          bytes: i.video.bytes,
          contentType: i.video.contentType,
          headers: value.uploadHeaders,
          onProgress: i.onProgress,
        );
        if (up case Err(:final failure)) return Err(failure);
        // Best effort: if this fails the server's reconcile job still finds
        // the file, and the upload page keeps polling the reel's status.
        final done = await _r.completeUpload(value.reel.id);
        return Success(switch (done) {
          Success(:final value) => value,
          Err() => value.reel,
        });
    }
  }
}
