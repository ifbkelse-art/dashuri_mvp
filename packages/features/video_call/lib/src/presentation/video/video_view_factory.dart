import 'package:flutter/widgets.dart';

/// Provider-specific video surfaces for the founder's call page. The
/// provider adapter implements this; pages place the returned widgets.
abstract interface class VideoViewFactory {
  Widget localPreview();

  Widget remoteVideo();
}
