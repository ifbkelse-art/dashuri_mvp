import 'package:dashuri_core/dashuri_core.dart';

import '../../../domain/entities/call_credentials.dart';
import '../../../domain/entities/media_event.dart';
import '../../../domain/ports/video_engine.dart';

/// Stream Video adapter. NOT IMPLEMENTED: the Stream SDK is not added yet,
/// pending commercial and technical validation (ADR-005).
///
/// TODO(video): add `stream_video_flutter`, then
///  - join: connect the Stream client with `credentials.userToken`, join
///    `credentials.providerCallId` (audio+video, front camera).
///  - events: map SDK call-state changes to [MediaEvent]s.
///  - leave: leave the call and disconnect the client.
///  - expose video views to the presentation layer through
///    `presentation/video/video_view_factory.dart`.
final class StreamVideoEngine implements VideoEngine {
  const StreamVideoEngine();

  static const _notImplemented = PlatformFailure(
    code: 'video_provider_not_implemented',
  );

  @override
  Future<Result<void>> join(CallCredentials credentials) async =>
      const Err(_notImplemented);

  @override
  Future<void> leave() async {}

  @override
  Future<void> setMicrophoneEnabled({required bool enabled}) async {}

  @override
  Future<void> setCameraEnabled({required bool enabled}) async {}

  @override
  Stream<MediaEvent> events() => const Stream.empty();
}
