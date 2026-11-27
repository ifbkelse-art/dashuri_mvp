import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/reel.dart';

/// Callbacks a real player reports (analytics and completion).
final class ReelPlayerCallbacks {
  const ReelPlayerCallbacks({
    required this.onStarted,
    required this.onCompleted,
    required this.onStopped,
  });

  final VoidCallback onStarted;

  /// Watched milliseconds when the video reached its end.
  final void Function(int watchedMs) onCompleted;

  /// Watched milliseconds when the user swiped away before the end.
  final void Function(int watchedMs) onStopped;
}

/// Video playback port. `VideoPlayerReelFactory` (video_player) is the
/// real implementation, registered by `registerReelsFeature`. Without a
/// factory, [ReelPosterView] says clearly that playback is unavailable: no
/// fake player, no dead controls.
abstract interface class ReelPlayerFactory {
  /// [preload]: the reel right after the active one. Implementations may
  /// open it paused and muted so swiping starts instantly; every other
  /// inactive reel must hold no player.
  Widget build({
    required ReelPlayback playback,
    required bool active,
    required bool muted,
    required bool paused,
    required ReelPlayerCallbacks callbacks,
    bool preload = false,
  });
}

/// Poster frame with an honest "playback unavailable" label.
class ReelPosterView extends StatelessWidget {
  const ReelPosterView({required this.playback, super.key});

  final ReelPlayback? playback;

  @override
  Widget build(BuildContext context) {
    final url = playback?.thumbnailUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: DashuriTokens.neutral900),
        if (url != null)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        Align(
          alignment: const Alignment(0, -0.35),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DashuriTokens.space3,
              vertical: DashuriTokens.space2,
            ),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: DashuriTokens.space2),
                Flexible(
                  child: Text(
                    'Video playback isn\'t available in this build',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
