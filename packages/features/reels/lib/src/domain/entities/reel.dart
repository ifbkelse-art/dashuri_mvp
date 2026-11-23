import 'package:equatable/equatable.dart';

/// Lifecycle of an uploaded reel (server state machine, docs/reels).
enum ReelStatus {
  awaitingUpload,
  processing,
  pendingModeration,
  inReview,
  published,
  rejected,
  removed,
  failed,
  deleted;

  static ReelStatus parse(String s) => switch (s) {
    'awaiting_upload' => awaitingUpload,
    'processing' => processing,
    'pending_moderation' => pendingModeration,
    'in_review' => inReview,
    'published' => published,
    'rejected' => rejected,
    'removed' => removed,
    'failed' => failed,
    _ => deleted,
  };

  /// Still moving through upload, processing or moderation.
  bool get isInFlight =>
      this == awaitingUpload ||
      this == processing ||
      this == pendingModeration ||
      this == inReview;

  /// The creator may appeal these.
  bool get isAppealable => this == rejected || this == removed;
}

/// Host facts shown with a creator who is an approved host. Null for
/// regular creators: only approved hosts get the call CTA.
final class ReelHost extends Equatable {
  const ReelHost({
    required this.availability,
    required this.ratePerMinute,
    required this.isVerified,
  });

  /// `online`, `busy` or `offline`.
  final String availability;
  final int ratePerMinute;
  final bool isVerified;

  bool get isOnline => availability == 'online';

  @override
  List<Object?> get props => [availability, ratePerMinute, isVerified];
}

final class ReelCreator extends Equatable {
  const ReelCreator({
    required this.userId,
    required this.displayName,
    required this.followedByMe,
    this.photoUrl,
    this.host,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final bool followedByMe;
  final ReelHost? host;

  ReelCreator copyWith({bool? followedByMe}) => ReelCreator(
    userId: userId,
    displayName: displayName,
    photoUrl: photoUrl,
    followedByMe: followedByMe ?? this.followedByMe,
    host: host,
  );

  @override
  List<Object?> get props => [
    userId,
    displayName,
    photoUrl,
    followedByMe,
    host,
  ];
}

/// Short-lived signed playback URLs (never stored).
final class ReelPlayback extends Equatable {
  const ReelPlayback({
    required this.hlsUrl,
    required this.thumbnailUrl,
    required this.expiresAt,
  });

  final String hlsUrl;
  final String thumbnailUrl;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [hlsUrl, thumbnailUrl, expiresAt];
}

final class Reel extends Equatable {
  const Reel({
    required this.id,
    required this.creator,
    required this.caption,
    required this.status,
    required this.likeCount,
    required this.viewCount,
    required this.shareCount,
    required this.likedByMe,
    required this.isMine,
    required this.createdAt,
    this.language,
    this.durationMs,
    this.rejectionCode,
    this.playback,
    this.publishedAt,
  });

  final String id;
  final ReelCreator creator;
  final String caption;
  final String? language;
  final int? durationMs;
  final ReelStatus status;
  final String? rejectionCode;
  final int likeCount;
  final int viewCount;
  final int shareCount;
  final bool likedByMe;
  final bool isMine;
  final ReelPlayback? playback;
  final DateTime? publishedAt;
  final DateTime createdAt;

  Reel copyWith({
    bool? likedByMe,
    int? likeCount,
    ReelCreator? creator,
    int? shareCount,
  }) => Reel(
    id: id,
    creator: creator ?? this.creator,
    caption: caption,
    language: language,
    durationMs: durationMs,
    status: status,
    rejectionCode: rejectionCode,
    likeCount: likeCount ?? this.likeCount,
    viewCount: viewCount,
    shareCount: shareCount ?? this.shareCount,
    likedByMe: likedByMe ?? this.likedByMe,
    isMine: isMine,
    playback: playback,
    publishedAt: publishedAt,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    creator,
    caption,
    language,
    durationMs,
    status,
    rejectionCode,
    likeCount,
    viewCount,
    shareCount,
    likedByMe,
    isMine,
    playback,
    publishedAt,
    createdAt,
  ];
}

enum FeedTab {
  forYou('for_you'),
  following('following');

  const FeedTab(this.wire);
  final String wire;
}
