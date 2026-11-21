import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_video_call/src/data/providers/stream/jpeg_encoder.dart';
import 'package:feature_video_call/src/data/providers/stream/stream_moderation_frame_source.dart';
import 'package:feature_video_call/src/data/providers/stream/stream_video_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _gradient(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      px[i] = (x * 255 ~/ w);
      px[i + 1] = (y * 255 ~/ h);
      px[i + 2] = 128;
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  testWidgets('JPEG encoder output decodes with the platform codec', (t) async {
    await t.runAsync(() async {
      final jpeg = JpegEncoder().encode(_gradient(37, 21), 37, 21);
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      expect(jpeg.sublist(jpeg.length - 2), [0xFF, 0xD9]);
      final codec = await ui.instantiateImageCodec(jpeg);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 37);
      expect(frame.image.height, 21);
      final data = (await frame.image.toByteData())!;
      // The centre pixel is close to the source colour.
      final i = (10 * 37 + 18) * 4;
      expect((data.getUint8(i) - 18 * 255 ~/ 37).abs(), lessThan(24));
      expect((data.getUint8(i + 2) - 128).abs(), lessThan(24));
    });
  });

  testWidgets('large frames are downscaled under 200 KB', (t) async {
    await t.runAsync(() async {
      // A noisy 1280×720 frame encoded at high quality is far above 200 KB.
      final w = 1280, h = 720;
      final px = _gradient(w, h);
      for (var i = 0; i < px.length; i += 4) {
        px[i] = (i * 7919) & 0xFF;
        px[i + 1] = (i * 104729) & 0xFF;
      }
      final big = JpegEncoder(quality: 100).encode(px, w, h);
      expect(big.length, greaterThan(ModerationFrame.maxBytes));
      final fitted = await StreamModerationFrameSource.fitJpeg(big);
      expect(fitted, isNotNull);
      expect(fitted!.length, lessThanOrEqualTo(ModerationFrame.maxBytes));
      expect(fitted.sublist(0, 2), [0xFF, 0xD8]);
    });
  });

  group('StreamVideoEngine configuration errors', () {
    CallCredentials creds({String provider = 'stream', String? apiKey}) =>
        CallCredentials(
          provider: provider,
          providerCallId: 'default:c1',
          userToken: 'a.b.c',
          expiresAt: DateTime.utc(2030),
          apiKey: apiKey,
        );

    test('missing api key → video_not_configured', () async {
      final r = await StreamVideoEngine().join(creds());
      expect((r as Err).failure.code, 'video_not_configured');
    });

    test('other provider → video_provider_unsupported', () async {
      final r = await StreamVideoEngine().join(creds(provider: 'zego'));
      expect((r as Err).failure.code, 'video_provider_unsupported');
    });

    test('token without a user id → video_credentials_invalid', () async {
      final r = await StreamVideoEngine().join(creds(apiKey: 'k'));
      expect((r as Err).failure.code, 'video_credentials_invalid');
    });
  });
}
