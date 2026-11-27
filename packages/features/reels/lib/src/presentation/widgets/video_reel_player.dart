import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/reel.dart';
import 'reel_player.dart';

/// What the reel player needs to know about a video (a seam over
/// `VideoPlayerValue`, so widget tests need no platform player).
final class ReelVideoState {
  const ReelVideoState({
    this.initialized = false,
    this.playing = false,
    this.buffering = false,
    this.hasError = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 9 / 16,
  });

  final bool initialized;
  final bool playing;
  final bool buffering;
  final bool hasError;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
}

/// The controller operations the reel player uses.
abstract interface class ReelVideoController implements Listenable {
  ReelVideoState get value;
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> setVolume(double volume);
  Future<void> setLooping(bool looping);
  Future<void> seekTo(Duration position);

  /// The video surface.
  Widget view();
  Future<void> dispose();
}

typedef ReelVideoControllerFactory = ReelVideoController Function(String url);

/// [ReelVideoController] over `video_player` (ExoPlayer on Android).
final class _PlatformReelVideoController implements ReelVideoController {
  _PlatformReelVideoController(String url)
    : _c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        // Stops other apps' audio while a reel plays sound.
        videoPlayerOptions: VideoPlayerOptions(),
      );

  final VideoPlayerController _c;

  @override
  ReelVideoState get value {
    final v = _c.value;
    return ReelVideoState(
      initialized: v.isInitialized,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      hasError: v.hasError,
      position: v.position,
      duration: v.duration,
      aspectRatio: v.isInitialized && v.aspectRatio > 0
          ? v.aspectRatio
          : 9 / 16,
    );
  }

  @override
  void addListener(VoidCallback l) => _c.addListener(l);
  @override
  void removeListener(VoidCallback l) => _c.removeListener(l);
  @override
  Future<void> initialize() => _c.initialize();
  @override
  Future<void> play() => _c.play();
  @override
  Future<void> pause() => _c.pause();
  @override
  Future<void> setVolume(double volume) => _c.setVolume(volume);
  @override
  Future<void> setLooping(bool looping) => _c.setLooping(looping);
  @override
  Future<void> seekTo(Duration position) => _c.seekTo(position);
  @override
  Widget view() => VideoPlayer(_c);
  @override
  Future<void> dispose() => _c.dispose();
}

/// Real playback for Reels (progressive MP4 from short-lived R2 URLs).
///
/// Memory and data: a controller exists only for the active reel and the
/// next one (preloaded, paused, muted); every other reel holds none, so at
/// most two videos are ever open.
///
/// Playback stops when the reel is not active, the user paused, the app is
/// in the background, or the feed is not on screen (another tab, or a route
/// pushed on top such as an incoming call or a creator profile: both turn
/// [TickerMode] off for the feed).
final class VideoPlayerReelFactory implements ReelPlayerFactory {
  const VideoPlayerReelFactory({ReelVideoControllerFactory? create})
    : _create = create;

  final ReelVideoControllerFactory? _create;

  @override
  Widget build({
    required ReelPlayback playback,
    required bool active,
    required bool muted,
    required bool paused,
    required ReelPlayerCallbacks callbacks,
    bool preload = false,
  }) => ReelVideoPlayer(
    key: ValueKey(playback.url),
    playback: playback,
    active: active,
    preload: preload,
    muted: muted,
    paused: paused,
    callbacks: callbacks,
    create: _create ?? _PlatformReelVideoController.new,
  );
}

class ReelVideoPlayer extends StatefulWidget {
  const ReelVideoPlayer({
    required this.playback,
    required this.active,
    required this.preload,
    required this.muted,
    required this.paused,
    required this.callbacks,
    required this.create,
    super.key,
  });

  final ReelPlayback playback;
  final bool active, preload, muted, paused;
  final ReelPlayerCallbacks callbacks;
  final ReelVideoControllerFactory create;

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer>
    with WidgetsBindingObserver {
  ReelVideoController? _controller;
  ReelVideoState _value = const ReelVideoState();
  bool _failed = false;
  bool _foreground = true;
  bool _onScreen = true;
  bool _started = false; // playStarted reported for this activation
  bool _completed = false; // playCompleted reported for this activation

  bool get _wanted => widget.active || widget.preload;
  bool get _shouldPlay =>
      widget.active && !widget.paused && _foreground && _onScreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onScreen = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(ReelVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) _endActivation(rewind: true);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.active) _endActivation(rewind: false);
    _release();
    super.dispose();
  }

  /// Reports how much was watched when the reel stops being active before
  /// it reached its end; resets the per-activation flags.
  void _endActivation({required bool rewind}) {
    final c = _controller;
    if (_started && !_completed) {
      widget.callbacks.onStopped(_value.position.inMilliseconds);
    }
    _started = false;
    _completed = false;
    if (rewind && c != null && _value.initialized) {
      unawaited(c.pause());
      unawaited(c.seekTo(Duration.zero));
    }
  }

  void _sync() {
    if (!_wanted) {
      _release();
      return;
    }
    final c = _controller ?? (_failed ? null : _open());
    if (c == null || !_value.initialized) return;
    unawaited(c.setVolume(widget.muted || !widget.active ? 0 : 1));
    if (_shouldPlay && !_value.playing) {
      unawaited(c.play());
    } else if (!_shouldPlay && _value.playing) {
      unawaited(c.pause());
    }
  }

  ReelVideoController _open() {
    final c = widget.create(widget.playback.url);
    _controller = c;
    c.addListener(_onValue);
    unawaited(_initialize(c));
    return c;
  }

  Future<void> _initialize(ReelVideoController c) async {
    try {
      await c.initialize();
      await c.setLooping(true);
    } on Object {
      if (identical(c, _controller) && mounted) {
        setState(() => _failed = true);
        _release();
      }
      return;
    }
    if (!identical(c, _controller) || !mounted) return;
    _onValue();
    _sync();
  }

  void _onValue() {
    final c = _controller;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.hasError) {
      setState(() => _failed = true);
      _release();
      return;
    }
    if (widget.active && v.playing && !_started) {
      _started = true;
      widget.callbacks.onStarted();
    }
    // Looping: report the first time the end is reached in this activation.
    final d = v.duration;
    if (widget.active &&
        _started &&
        !_completed &&
        d > Duration.zero &&
        v.position >= d - const Duration(milliseconds: 300)) {
      _completed = true;
      widget.callbacks.onCompleted(d.inMilliseconds);
    }
    final changed =
        v.initialized != _value.initialized ||
        v.buffering != _value.buffering ||
        v.playing != _value.playing;
    _value = v;
    if (changed) setState(() {});
  }

  void _release() {
    final c = _controller;
    if (c == null) return;
    _controller = null;
    _value = const ReelVideoState();
    c.removeListener(_onValue);
    unawaited(c.dispose());
  }

  void _retry() {
    setState(() => _failed = false);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && _value.initialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        // The poster stays until the first frame can be shown.
        if (!ready && widget.playback.thumbnailUrl.isNotEmpty)
          Image.network(
            widget.playback.thumbnailUrl,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (ready)
          Semantics(
            label: 'Reel video',
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 1000 * _value.aspectRatio,
                height: 1000,
                child: c.view(),
              ),
            ),
          ),
        if (widget.active && !_failed && (!ready || _value.buffering))
          const Center(
            child: SizedBox.square(
              dimension: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white70,
                semanticsLabel: 'Loading video',
              ),
            ),
          ),
        if (widget.active && _failed)
          Center(child: _PlaybackError(onRetry: _retry)),
      ],
    );
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: DashuriTokens.space6),
    padding: const EdgeInsets.all(DashuriTokens.space4),
    decoration: BoxDecoration(
      color: DashuriColors.mediaScrim,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 32),
        const SizedBox(height: DashuriTokens.space2),
        const Text(
          "Couldn't play this reel. Check your connection.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(height: DashuriTokens.space3),
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
