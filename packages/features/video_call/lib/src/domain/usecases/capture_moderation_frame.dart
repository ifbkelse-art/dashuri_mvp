import 'package:dashuri_core/dashuri_core.dart';

import '../entities/moderation_frame.dart';
import '../ports/moderation_frame_source.dart';

/// Captures one frame of the local outgoing camera.
// Not final: application tests mock use cases.
class CaptureModerationFrame implements UseCase<ModerationFrame, NoInput> {
  const CaptureModerationFrame(this._source);

  final ModerationFrameSource _source;

  @override
  Future<Result<ModerationFrame>> call(NoInput input) => _source.capture();
}
