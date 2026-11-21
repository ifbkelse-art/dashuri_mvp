import 'package:dashuri_core/dashuri_core.dart';

import '../entities/moderation_frame.dart';

/// Captures one JPEG (≤ 200 KB) of the user's own outgoing camera for the
/// S7 safety check. Implemented by the video provider adapter.
abstract interface class ModerationFrameSource {
  Future<Result<ModerationFrame>> capture();
}
