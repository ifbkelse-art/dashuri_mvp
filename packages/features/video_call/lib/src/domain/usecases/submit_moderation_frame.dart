import 'dart:convert';

import 'package:dashuri_core/dashuri_core.dart';

import '../entities/moderation_frame.dart';
import '../repositories/call_repository.dart';

/// POST /v1/calls/{callId}/moderation-frames with a base64 JPEG (S7).
// Not final: application tests mock use cases.
class SubmitModerationFrame
    implements UseCase<bool, ({String callId, ModerationFrame frame})> {
  const SubmitModerationFrame(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<bool>> call(({String callId, ModerationFrame frame}) input) =>
      _repository.submitModerationFrame(
        callId: input.callId,
        imageBase64: base64Encode(input.frame.jpegBytes),
        capturedAt: input.frame.capturedAt,
      );
}
