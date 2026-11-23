import 'package:equatable/equatable.dart';

/// Where the video comes from (R1 record, R2 gallery).
enum ReelVideoSource { camera, gallery }

/// A video picked or recorded by the user, ready to upload.
final class PickedVideo extends Equatable {
  const PickedVideo({
    required this.bytes,
    required this.contentType,
    this.name = 'reel.mp4',
  });

  final List<int> bytes;

  /// `video/mp4` or `video/quicktime`.
  final String contentType;
  final String name;

  @override
  List<Object?> get props => [bytes.length, contentType, name];
}

/// Device camera / gallery access. Implemented in the app with the
/// existing `image_picker` dependency (camera recording is capped at 60 s).
/// When none is registered, the upload page says recording is unavailable
/// instead of showing dead buttons.
abstract interface class ReelVideoPicker {
  /// Null when the user cancelled.
  Future<PickedVideo?> pick(ReelVideoSource source);
}

/// Reads the duration of an MP4/QuickTime file from its `mvhd` box, so the
/// app can check the 15–60 s rule before uploading (the server re-checks
/// the real duration reported by the video provider). Pure Dart.
abstract final class Mp4Duration {
  /// Milliseconds, or null when the file has no readable `moov/mvhd`.
  static int? read(List<int> b) {
    final moov = _find(b, 0, b.length, 'moov');
    if (moov == null) return null;
    final mvhd = _find(b, moov.$1, moov.$2, 'mvhd');
    if (mvhd == null) return null;
    var p = mvhd.$1;
    if (p + 4 > b.length) return null;
    final version = b[p];
    p += 4; // version + flags
    int timescale;
    int duration;
    if (version == 1) {
      if (p + 28 > b.length) return null;
      p += 16; // creation + modification (8 bytes each)
      timescale = _u32(b, p);
      duration = _u32(b, p + 4) * 0x100000000 + _u32(b, p + 8);
    } else {
      if (p + 16 > b.length) return null;
      p += 8; // creation + modification (4 bytes each)
      timescale = _u32(b, p);
      duration = _u32(b, p + 4);
    }
    if (timescale <= 0) return null;
    return (duration * 1000 / timescale).round();
  }

  /// Finds a child box of [type] in [start, end); returns its payload range.
  static (int, int)? _find(List<int> b, int start, int end, String type) {
    var p = start;
    while (p + 8 <= end) {
      var size = _u32(b, p);
      final t = String.fromCharCodes(b.sublist(p + 4, p + 8));
      var header = 8;
      if (size == 1) {
        if (p + 16 > end) return null;
        size = _u32(b, p + 8) * 0x100000000 + _u32(b, p + 12);
        header = 16;
      } else if (size == 0) {
        size = end - p;
      }
      if (size < header || p + size > end) return null;
      if (t == type) return (p + header, p + size);
      p += size;
    }
    return null;
  }

  static int _u32(List<int> b, int p) =>
      (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
}
