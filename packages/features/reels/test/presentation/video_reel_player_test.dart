import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the player asks of the video.
final class _FakeVideo extends ChangeNotifier implements ReelVideoController {
  _FakeVideo(this.url, {this.failInit = false});

  final String url;
  final bool failInit;
  ReelVideoState _v = const ReelVideoState();
  final calls = <String>[];
  double volume = 1;
  bool disposed = false;

  @override
  ReelVideoState get value => _v;

  void set({Duration? position, bool? playing, bool? buffering}) {
    _v = ReelVideoState(
      initialized: _v.initialized,
      playing: playing ?? _v.playing,
      buffering: buffering ?? _v.buffering,
      position: position ?? _v.position,
      duration: _v.duration,
    );
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    calls.add('init');
    if (failInit) throw Exception('network');
    _v = const ReelVideoState(
      initialized: true,
      duration: Duration(seconds: 20),
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    set(playing: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    set(playing: false);
  }

  @override
  Future<void> seekTo(Duration p) async {
    calls.add('seek:${p.inMilliseconds}');
    set(position: p);
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Widget view() => const ColoredBox(color: Colors.blue);

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }
}

final _pb = ReelPlayback(
  url: 'https://r2.example/r1/playback.mp4?sig',
  thumbnailUrl: '',
  expiresAt: DateTime.utc(2030),
);

void main() {
  setUpAll(() => DashuriText.useGoogleFonts = false);

  late List<_FakeVideo> videos;
  late List<String> events;
  late bool failNext;

  setUp(() {
    videos = [];
    events = [];
    failNext = false;
  });

  ReelPlayerCallbacks callbacks() => ReelPlayerCallbacks(
    onStarted: () => events.add('started'),
    onCompleted: (ms) => events.add('completed:$ms'),
    onStopped: (ms) => events.add('stopped:$ms'),
  );

  ReelPlayerFactory factory() => VideoPlayerReelFactory(
    create: (url) {
      final v = _FakeVideo(url, failInit: failNext);
      failNext = false;
      videos.add(v);
      return v;
    },
  );

  Widget host({
    bool active = true,
    bool preload = false,
    bool muted = true,
    bool paused = false,
    bool tickers = true,
  }) => MaterialApp(
    home: TickerMode(
      enabled: tickers,
      child: factory().build(
        playback: _pb,
        active: active,
        preload: preload,
        muted: muted,
        paused: paused,
        callbacks: callbacks(),
      ),
    ),
  );

  testWidgets('an off-screen reel holds no player', (t) async {
    await t.pumpWidget(host(active: false));
    await t.pump();
    expect(videos, isEmpty);
  });

  testWidgets('the active reel plays muted and reports its start once', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pump();
    final v = videos.single;
    expect(v.url, _pb.url);
    expect(v.calls, containsAllInOrder(['init', 'play']));
    expect(v.volume, 0);
    expect(events, ['started']);
    // Unmute.
    await t.pumpWidget(host(muted: false));
    await t.pump();
    expect(v.volume, 1);
    expect(events, ['started']);
  });

  testWidgets('the next reel is preloaded paused and silent', (t) async {
    await t.pumpWidget(host(active: false, preload: true));
    await t.pump();
    final v = videos.single;
    expect(v.calls, ['init']);
    expect(v.volume, 0);
    expect(events, isEmpty);
    // Swiping to it plays the same controller (no second download).
    await t.pumpWidget(host());
    await t.pump();
    expect(videos, hasLength(1));
    expect(v.calls.last, 'play');
  });

  testWidgets('swiping away reports watch time, rewinds, and frees memory', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pump();
    final v = videos.single..set(position: const Duration(seconds: 7));
    await t.pumpWidget(host(active: false));
    await t.pump();
    expect(events, ['started', 'stopped:7000']);
    expect(v.calls, containsAllInOrder(['pause', 'seek:0']));
    expect(v.disposed, isTrue);
  });

  testWidgets('reaching the end reports completion once while looping', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pump();
    final v = videos.single
      ..set(position: const Duration(milliseconds: 19900))
      ..set(position: Duration.zero)
      ..set(position: const Duration(milliseconds: 19950));
    expect(events.where((e) => e.startsWith('completed')), ['completed:20000']);
    await t.pumpWidget(host(active: false));
    await t.pump();
    expect(events.where((e) => e.startsWith('stopped')), isEmpty);
    expect(v.disposed, isTrue);
  });

  testWidgets('user pause, background and a covering route all stop it', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pump();
    final v = videos.single;

    await t.pumpWidget(host(paused: true));
    await t.pump();
    expect(v.value.playing, isFalse);
    await t.pumpWidget(host());
    await t.pump();
    expect(v.value.playing, isTrue);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(v.value.playing, isFalse, reason: 'app in background');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(v.value.playing, isTrue, reason: 'back in the foreground');

    // An incoming call / profile pushed on top, or another tab.
    await t.pumpWidget(host(tickers: false));
    await t.pump();
    expect(v.value.playing, isFalse, reason: 'feed not on screen');
  });

  testWidgets('a network failure shows Try again, which reopens the video', (
    t,
  ) async {
    failNext = true;
    await t.pumpWidget(host());
    await t.pump();
    await t.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(videos.single.disposed, isTrue);

    await t.tap(find.text('Try again'));
    await t.pump();
    await t.pump();
    expect(videos, hasLength(2));
    expect(videos.last.calls, containsAllInOrder(['init', 'play']));
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a buffering video shows a progress indicator', (t) async {
    await t.pumpWidget(host());
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    videos.single.set(buffering: true);
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('leaving the feed disposes the player', (t) async {
    await t.pumpWidget(host());
    await t.pump();
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pump();
    expect(videos.single.disposed, isTrue);
  });
}
