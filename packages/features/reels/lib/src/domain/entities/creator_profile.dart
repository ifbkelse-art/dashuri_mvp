import 'package:equatable/equatable.dart';

import 'reel.dart';

final class CreatorProfile extends Equatable {
  const CreatorProfile({
    required this.creator,
    required this.followerCount,
    required this.followingCount,
    required this.reelCount,
    required this.isSelf,
    this.bio,
  });

  final ReelCreator creator;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final int reelCount;
  final bool isSelf;

  CreatorProfile copyWith({bool? followedByMe, int? followerCount}) =>
      CreatorProfile(
        creator: creator.copyWith(followedByMe: followedByMe),
        bio: bio,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        reelCount: reelCount,
        isSelf: isSelf,
      );

  @override
  List<Object?> get props => [
    creator,
    bio,
    followerCount,
    followingCount,
    reelCount,
    isSelf,
  ];
}

/// GET /v1/reels/config: whether Reels and uploads work on this server.
final class ReelsConfig extends Equatable {
  const ReelsConfig({
    required this.enabled,
    required this.uploadsAvailable,
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.maxCaptionLength,
    required this.maxUploadBytes,
  });

  final bool enabled;
  final bool uploadsAvailable;
  final int minDurationMs;
  final int maxDurationMs;
  final int maxCaptionLength;
  final int maxUploadBytes;

  @override
  List<Object?> get props => [
    enabled,
    uploadsAvailable,
    minDurationMs,
    maxDurationMs,
    maxCaptionLength,
    maxUploadBytes,
  ];
}

/// Report categories accepted by POST /v1/reels/{id}/reports.
enum ReelReportCategory {
  nudity('nudity', 'Nudity'),
  sexualContent('sexual_content', 'Sexual content'),
  minorSafety('minor_safety', 'Someone may be under 18'),
  harassment('harassment', 'Harassment or bullying'),
  violence('violence', 'Violence or graphic content'),
  hate('hate', 'Hate speech'),
  spamOrScam('spam_or_scam', 'Spam or scam'),
  copyright('copyright', 'Copyright or music I own'),
  privacy('privacy', 'Shares private information'),
  other('other', 'Something else');

  const ReelReportCategory(this.wire, this.label);
  final String wire;
  final String label;
}

/// Client analytics events (the server records likes, follows, shares and
/// reports itself).
enum ReelEventName {
  impression('reel_impression'),
  playStarted('reel_play_started'),
  playCompleted('reel_play_completed'),
  watchDuration('reel_watch_duration'),
  creatorProfileOpened('creator_profile_opened'),
  hostCallCtaClicked('host_call_cta_clicked');

  const ReelEventName(this.wire);
  final String wire;
}

final class ReelEvent extends Equatable {
  const ReelEvent({
    required this.name,
    this.reelId,
    this.creatorId,
    this.valueMs,
    this.sessionId,
  });

  final ReelEventName name;
  final String? reelId;
  final String? creatorId;
  final int? valueMs;
  final String? sessionId;

  @override
  List<Object?> get props => [name, reelId, creatorId, valueMs, sessionId];
}
