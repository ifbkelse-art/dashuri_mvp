import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:mocktail/mocktail.dart';

class MockReelsRepository extends Mock implements ReelsRepository {}

class MockPicker extends Mock implements ReelVideoPicker {}

const config = ReelsConfig(
  enabled: true,
  uploadsAvailable: true,
  minDurationMs: 15000,
  maxDurationMs: 60000,
  maxCaptionLength: 300,
  maxUploadBytes: 150 << 20,
);

const host = ReelHost(
  availability: 'online',
  ratePerMinute: 1500,
  isVerified: true,
);

ReelCreator creator(String id, {ReelHost? host, bool followed = false}) =>
    ReelCreator(
      userId: id,
      displayName: 'Creator $id',
      followedByMe: followed,
      host: host,
    );

Reel reel(
  String id, {
  ReelCreator? by,
  ReelStatus status = ReelStatus.published,
  bool mine = false,
  int likes = 3,
  bool liked = false,
  String? rejection,
  String? caption,
}) => Reel(
  id: id,
  creator: by ?? creator('c-$id'),
  caption: caption ?? 'Caption $id',
  status: status,
  likeCount: likes,
  viewCount: 10,
  shareCount: 0,
  likedByMe: liked,
  isMine: mine,
  rejectionCode: rejection,
  createdAt: DateTime.utc(2026, 11, 22),
  playback: ReelPlayback(
    url: 'https://play.example/$id/playback.mp4',
    thumbnailUrl: 'https://img.example/$id.jpg',
    expiresAt: DateTime.utc(2026, 11, 23),
  ),
);

Page<Reel> page(List<Reel> items, [String? next]) =>
    Page(items: items, nextCursor: next);

/// A minimal MP4: `ftyp` + `moov/mvhd` (version 0) with the given duration.
List<int> mp4(int durationMs, {int timescale = 1000, int version = 0}) {
  List<int> u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];
  List<int> box(String type, List<int> payload) => [
    ...u32(payload.length + 8),
    ...type.codeUnits,
    ...payload,
  ];
  final dur = durationMs * timescale ~/ 1000;
  final mvhd = version == 0
      ? [
          0,
          0,
          0,
          0,
          ...u32(0),
          ...u32(0),
          ...u32(timescale),
          ...u32(dur),
          ...List.filled(80, 0),
        ]
      : [
          1,
          0,
          0,
          0,
          ...u32(0),
          ...u32(0),
          ...u32(0),
          ...u32(0),
          ...u32(timescale),
          ...u32(0),
          ...u32(dur),
          ...List.filled(80, 0),
        ];
  return [
    ...box('ftyp', 'isom'.codeUnits + [0, 0, 2, 0]),
    ...box('free', List.filled(16, 0)),
    ...box('moov', box('mvhd', mvhd)),
  ];
}
