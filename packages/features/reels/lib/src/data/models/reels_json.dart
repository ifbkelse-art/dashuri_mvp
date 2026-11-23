import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/creator_profile.dart';
import '../../domain/entities/reel.dart';

ReelHost? _host(Object? json) {
  if (json is! JsonMap) return null;
  return ReelHost(
    availability: json['availability']! as String,
    ratePerMinute: json['rate_per_minute']! as int,
    isVerified: json['is_verified']! as bool,
  );
}

ReelCreator creatorFromJson(JsonMap j) => ReelCreator(
  userId: j['user_id']! as String,
  displayName: j['display_name']! as String,
  photoUrl: j['photo_url'] as String?,
  followedByMe: j['followed_by_me']! as bool,
  host: _host(j['host']),
);

ReelPlayback? _playback(Object? json) {
  if (json is! JsonMap) return null;
  return ReelPlayback(
    hlsUrl: json['hls_url']! as String,
    thumbnailUrl: json['thumbnail_url']! as String,
    expiresAt: DateTime.parse(json['expires_at']! as String),
  );
}

DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;

Reel reelFromJson(JsonMap j) => Reel(
  id: j['id']! as String,
  creator: creatorFromJson(j['creator']! as JsonMap),
  caption: j['caption']! as String,
  language: j['language'] as String?,
  durationMs: j['duration_ms'] as int?,
  status: ReelStatus.parse(j['status']! as String),
  rejectionCode: j['rejection_code'] as String?,
  likeCount: j['like_count']! as int,
  viewCount: j['view_count']! as int,
  shareCount: j['share_count']! as int,
  likedByMe: j['liked_by_me']! as bool,
  isMine: j['is_mine']! as bool,
  playback: _playback(j['playback']),
  publishedAt: _date(j['published_at']),
  createdAt: DateTime.parse(j['created_at']! as String),
);

CreatorProfile creatorProfileFromJson(JsonMap j) => CreatorProfile(
  creator: creatorFromJson(j),
  bio: j['bio'] as String?,
  followerCount: j['follower_count']! as int,
  followingCount: j['following_count']! as int,
  reelCount: j['reel_count']! as int,
  isSelf: j['is_self']! as bool,
);

ReelsConfig reelsConfigFromJson(JsonMap j) => ReelsConfig(
  enabled: j['enabled']! as bool,
  uploadsAvailable: j['uploads_available']! as bool,
  minDurationMs: j['min_duration_ms']! as int,
  maxDurationMs: j['max_duration_ms']! as int,
  maxCaptionLength: j['max_caption_length']! as int,
  maxUploadBytes: j['max_upload_bytes']! as int,
);

JsonMap eventToJson(ReelEvent e) => {
  'event': e.name.wire,
  'reel_id': ?e.reelId,
  'creator_id': ?e.creatorId,
  'value_ms': ?e.valueMs,
  'session_id': ?e.sessionId,
};
