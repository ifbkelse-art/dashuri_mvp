import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' as sv;

import '../../../presentation/video/video_view_factory.dart';
import 'stream_video_engine.dart';

/// [VideoViewFactory] backed by `StreamVideoRenderer` for one
/// [StreamVideoEngine]. Views rebuild when the call joins and when
/// participants or tracks change.
final class StreamVideoViewFactory implements VideoViewFactory {
  const StreamVideoViewFactory(this._engine);

  final StreamVideoEngine _engine;

  @override
  Widget localPreview({Widget? placeholder}) =>
      _ParticipantVideo(engine: _engine, local: true, placeholder: placeholder);

  @override
  Widget remoteVideo({Widget? placeholder}) => _ParticipantVideo(
    engine: _engine,
    local: false,
    placeholder: placeholder,
  );
}

class _ParticipantVideo extends StatelessWidget {
  const _ParticipantVideo({
    required this.engine,
    required this.local,
    this.placeholder,
  });

  final StreamVideoEngine engine;
  final bool local;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final fallback = placeholder ?? const ColoredBox(color: Colors.black);
    return ValueListenableBuilder<sv.Call?>(
      valueListenable: engine.call,
      builder: (context, call, _) {
        if (call == null) return fallback;
        return StreamBuilder<sv.CallState>(
          stream: call.state.valueStream,
          initialData: call.state.value,
          builder: (context, snap) {
            final state = snap.data;
            final participant = state == null
                ? null
                : local
                ? state.localParticipant
                : (state.otherParticipants.isEmpty
                      ? null
                      : state.otherParticipants.first);
            if (participant == null) return fallback;
            return sv.StreamVideoRenderer(
              call: call,
              participant: participant,
              videoTrackType: sv.SfuTrackType.video,
              videoFit: sv.VideoFit.cover,
              placeholderBuilder: (_) => fallback,
            );
          },
        );
      },
    );
  }
}
