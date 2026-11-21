import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// One JPEG frame of the local outgoing camera (S7), at most 200 KB.
final class ModerationFrame extends Equatable {
  const ModerationFrame({required this.jpegBytes, required this.capturedAt});

  /// Maximum payload accepted by POST /v1/calls/{id}/moderation-frames.
  static const maxBytes = 200 * 1024;

  final Uint8List jpegBytes;
  final DateTime capturedAt;

  @override
  List<Object?> get props => [jpegBytes, capturedAt];
}
