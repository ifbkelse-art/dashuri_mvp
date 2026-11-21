import 'package:flutter/widgets.dart';

/// Provider-specific video surfaces for the call page. The provider adapter
/// implements this; pages place the returned widgets. [placeholder] is shown
/// while no video track is available (camera off, not yet received).
abstract interface class VideoViewFactory {
  Widget localPreview({Widget? placeholder});

  Widget remoteVideo({Widget? placeholder});
}
