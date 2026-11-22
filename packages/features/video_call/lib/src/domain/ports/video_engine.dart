import 'package:dashuri_core/dashuri_core.dart';

import '../entities/call_credentials.dart';
import '../entities/media_event.dart';

/// Video provider port (ADR-005). Stream Video is the adapter. Swapping
/// providers means a new adapter in `data/providers/`, nothing else in this
/// feature changes.
abstract interface class VideoEngine {
  Future<Result<void>> join(CallCredentials credentials);

  Future<void> leave();

  Future<void> setMicrophoneEnabled({required bool enabled});

  Future<void> setCameraEnabled({required bool enabled});

  Stream<MediaEvent> events();
}
