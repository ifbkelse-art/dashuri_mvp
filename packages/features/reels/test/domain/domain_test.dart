import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('Mp4Duration', () {
    test('reads version 0 and 1 mvhd boxes', () {
      expect(Mp4Duration.read(mp4(21500)), 21500);
      expect(Mp4Duration.read(mp4(59000, timescale: 600)), 59000);
      expect(Mp4Duration.read(mp4(30000, version: 1, timescale: 90000)), 30000);
    });

    test('returns null for files without moov/mvhd or truncated boxes', () {
      expect(Mp4Duration.read([]), isNull);
      expect(Mp4Duration.read('not a video at all'.codeUnits), isNull);
      final cut = mp4(20000);
      expect(Mp4Duration.read(cut.sublist(0, cut.length - 60)), isNull);
    });
  });

  group('validatePickedVideo', () {
    PickedVideo v(List<int> b) =>
        PickedVideo(bytes: b, contentType: 'video/mp4');

    test('accepts 15–60 s with encoder tolerance and clamps', () {
      expect(validatePickedVideo(v(mp4(30000)), config), isA<Success<int>>());
      final edge = validatePickedVideo(v(mp4(14500)), config);
      expect((edge as Success<int>).value, 15000);
    });

    test('rejects short, long, unreadable and too large', () {
      String? code(Result<int> r) => switch (r) {
        Err(:final failure) => failure.code,
        Success() => null,
      };
      expect(
        code(validatePickedVideo(v(mp4(9000)), config)),
        ReelUploadRule.tooShort,
      );
      expect(
        code(validatePickedVideo(v(mp4(75000)), config)),
        ReelUploadRule.tooLong,
      );
      expect(
        code(validatePickedVideo(v([1, 2, 3]), config)),
        ReelUploadRule.unreadableDuration,
      );
      const tiny = ReelsConfig(
        enabled: true,
        uploadsAvailable: true,
        minDurationMs: 15000,
        maxDurationMs: 60000,
        maxCaptionLength: 300,
        maxUploadBytes: 10,
      );
      expect(
        code(validatePickedVideo(v(mp4(30000)), tiny)),
        ReelUploadRule.tooLarge,
      );
    });
  });

  test('ReelStatus parsing and flags', () {
    expect(ReelStatus.parse('in_review'), ReelStatus.inReview);
    expect(ReelStatus.parse('published'), ReelStatus.published);
    expect(ReelStatus.parse('???'), ReelStatus.deleted);
    expect(ReelStatus.processing.isInFlight, isTrue);
    expect(ReelStatus.published.isInFlight, isFalse);
    expect(ReelStatus.removed.isAppealable, isTrue);
    expect(ReelStatus.failed.isAppealable, isFalse);
  });
}
