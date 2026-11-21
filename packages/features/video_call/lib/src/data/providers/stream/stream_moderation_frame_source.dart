import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dashuri_core/dashuri_core.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' as sv;

import '../../../domain/entities/moderation_frame.dart';
import '../../../domain/ports/moderation_frame_source.dart';
import 'jpeg_encoder.dart';
import 'stream_video_engine.dart';

/// Captures the local outgoing camera with `Call.takeScreenshot` (which uses
/// `MediaStreamTrack.captureFrame()` from stream_webrtc_flutter; Android
/// returns a full-size JPEG), then downscales and re-encodes it until it is
/// at most [ModerationFrame.maxBytes].
final class StreamModerationFrameSource implements ModerationFrameSource {
  StreamModerationFrameSource(this._engine, {Clock clock = const SystemClock()})
    : _clock = clock;

  final StreamVideoEngine _engine;
  final Clock _clock;

  static const _widths = [640, 480, 360, 240];

  @override
  Future<Result<ModerationFrame>> capture() async {
    final call = _engine.call.value;
    final local = call?.state.value.localParticipant;
    if (call == null || local == null) {
      return const Err(PlatformFailure(code: 'camera_not_publishing'));
    }
    try {
      final buffer = await call.takeScreenshot(
        local,
        trackType: sv.SfuTrackType.video,
      );
      if (buffer == null) {
        return const Err(PlatformFailure(code: 'camera_not_publishing'));
      }
      final capturedAt = _clock.now();
      final raw = buffer.asUint8List();
      final jpeg = await fitJpeg(raw);
      if (jpeg == null) {
        return const Err(PlatformFailure(code: 'frame_encode_failed'));
      }
      return Success(ModerationFrame(jpegBytes: jpeg, capturedAt: capturedAt));
    } on Object catch (e) {
      return Err(PlatformFailure(code: 'frame_capture_failed', message: '$e'));
    }
  }

  /// Returns [raw] if it is already a small JPEG; otherwise decodes it,
  /// downscales and re-encodes it as JPEG within the size limit.
  static Future<Uint8List?> fitJpeg(Uint8List raw) async {
    final isJpeg = raw.length > 3 && raw[0] == 0xFF && raw[1] == 0xD8;
    if (isJpeg && raw.length <= ModerationFrame.maxBytes) return raw;
    for (final width in _widths) {
      final codec = await ui.instantiateImageCodec(raw, targetWidth: width);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData();
      final w = image.width, h = image.height;
      image.dispose();
      codec.dispose();
      if (data == null) return null;
      final jpeg = JpegEncoder(quality: 70).encode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        w,
        h,
      );
      if (jpeg.length <= ModerationFrame.maxBytes) return jpeg;
    }
    return null;
  }
}
