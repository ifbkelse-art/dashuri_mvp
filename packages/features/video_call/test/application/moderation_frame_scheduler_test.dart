import 'dart:async';
import 'dart:typed_data';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Capture extends Mock implements CaptureModerationFrame {}

class _Submit extends Mock implements SubmitModerationFrame {}

final class _Clock implements Clock {
  DateTime value = DateTime.utc(2026, 11, 21, 12);

  @override
  DateTime now() => value;
}

final class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late _Capture capture;
  late _Submit submit;
  late _Clock clock;
  late List<_FakeTimer> timers;
  late ModerationFrameScheduler scheduler;
  final frame = ModerationFrame(
    jpegBytes: Uint8List.fromList([0xFF, 0xD8]),
    capturedAt: DateTime.utc(2026),
  );

  /// Advances the clock by the pending timer's delay and fires it.
  Future<void> fire() async {
    final t = timers.removeAt(0);
    expect(t.cancelled, isFalse);
    clock.value = clock.value.add(t.delay);
    t.callback();
    await Future<void>.delayed(Duration.zero);
  }

  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue((callId: '', frame: frame));
  });

  setUp(() {
    capture = _Capture();
    submit = _Submit();
    clock = _Clock();
    timers = [];
    scheduler = ModerationFrameScheduler(
      capture: capture,
      submit: submit,
      clock: clock,
      timerFactory: (d, cb) {
        final t = _FakeTimer(d, cb);
        timers.add(t);
        return t;
      },
    );
    when(() => capture(any())).thenAnswer((_) async => Success(frame));
    when(() => submit(any())).thenAnswer((_) async => const Success(true));
  });

  test(
    'first frame after 5 s, then every 20 s until the window ends',
    () async {
      scheduler.start(
        callId: 'c1',
        windowEndsAt: clock.now().add(const Duration(seconds: 180)),
      );
      expect(timers.single.delay, const Duration(seconds: 5));
      await fire();
      expect(timers.single.delay, const Duration(seconds: 20));
      // 5 + 20 * 8 = 165 s; the next tick (185 s) is past the window.
      for (var i = 0; i < 8; i++) {
        await fire();
      }
      expect(scheduler.submittedCount, 9);
      expect(timers, isEmpty);
      expect(scheduler.isRunning, isFalse);
      verify(() => submit(any())).called(9);
    },
  );

  test('stops on moderation_window_closed', () async {
    when(() => submit(any())).thenAnswer(
      (_) async =>
          const Err(BusinessRuleFailure(code: 'moderation_window_closed')),
    );
    scheduler.start(
      callId: 'c1',
      windowEndsAt: clock.now().add(const Duration(minutes: 3)),
    );
    await fire();
    expect(scheduler.isRunning, isFalse);
    expect(timers, isEmpty);
  });

  test('stops when the server says moderation is off', () async {
    when(() => submit(any())).thenAnswer((_) async => const Success(false));
    scheduler.start(
      callId: 'c1',
      windowEndsAt: clock.now().add(const Duration(minutes: 3)),
    );
    await fire();
    expect(scheduler.isRunning, isFalse);
  });

  test('a failed capture skips the frame and keeps the schedule', () async {
    when(() => capture(any())).thenAnswer(
      (_) async => const Err(PlatformFailure(code: 'camera_not_publishing')),
    );
    scheduler.start(
      callId: 'c1',
      windowEndsAt: clock.now().add(const Duration(minutes: 3)),
    );
    await fire();
    verifyNever(() => submit(any()));
    expect(scheduler.isRunning, isTrue);
    expect(timers.single.delay, const Duration(seconds: 20));
  });

  test('does not start after the window and stop cancels the timer', () {
    scheduler.start(
      callId: 'c1',
      windowEndsAt: clock.now().subtract(const Duration(seconds: 1)),
    );
    expect(scheduler.isRunning, isFalse);
    scheduler.start(
      callId: 'c1',
      windowEndsAt: clock.now().add(const Duration(minutes: 3)),
    );
    final t = timers.single;
    scheduler.stop();
    expect(t.cancelled, isTrue);
    expect(scheduler.isRunning, isFalse);
  });

  test('submits the call id and the captured frame', () async {
    scheduler.start(
      callId: 'c9',
      windowEndsAt: clock.now().add(const Duration(minutes: 3)),
    );
    await fire();
    final arg =
        verify(() => submit(captureAny())).captured.single
            as ({String callId, ModerationFrame frame});
    expect(arg.callId, 'c9');
    expect(arg.frame, frame);
  });
}
