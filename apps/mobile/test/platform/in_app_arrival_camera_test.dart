import 'dart:async';
import 'dart:typed_data';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_mobile/app/platform/in_app_arrival_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

/// Scripted camera: each open() takes the next outcome.
final class _FakeSession implements ArrivalCameraSession {
  _FakeSession(this.outcomes);

  final List<CameraProblem?> outcomes; // null = opens fine
  int opens = 0, closes = 0;
  bool failCapture = false;
  bool isOpen = false;

  @override
  Future<void> open() async {
    final o = outcomes.isEmpty ? null : outcomes.removeAt(0);
    opens++;
    if (o != null) throw CameraOpenException(o);
    isOpen = true;
  }

  @override
  Widget preview() => const ColoredBox(key: Key('preview'), color: Colors.teal);

  @override
  double get aspectRatio => 3 / 4;

  @override
  Future<Uint8List> takePicture() async {
    if (failCapture) throw Exception('busy');
    return _jpeg;
  }

  @override
  Future<void> close() async {
    closes++;
    isOpen = false;
  }
}

void main() {
  setUpAll(() => DashuriText.useGoogleFonts = false);

  /// Opens the camera page from a button; [result] gets what it popped.
  Future<Completer<Uint8List?>> open(WidgetTester t, _FakeSession s) async {
    final result = Completer<Uint8List?>();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.complete(
              await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute(
                  builder: (_) => ArrivalCameraPage(session: s),
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    return result;
  }

  testWidgets('front-camera preview → shutter returns the photo', (t) async {
    final s = _FakeSession([]);
    final result = await open(t, s);
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.textContaining('gallery'), findsNothing);
    await t.tap(find.bySemanticsLabel('Take photo'));
    await t.pumpAndSettle();
    expect(await result.future, _jpeg);
    expect(s.closes, greaterThanOrEqualTo(1), reason: 'camera released');
    expect(s.isOpen, isFalse);
  });

  testWidgets('close returns nothing and releases the camera', (t) async {
    final s = _FakeSession([]);
    final result = await open(t, s);
    await t.tap(find.byTooltip('Close camera'));
    await t.pumpAndSettle();
    expect(await result.future, isNull);
    expect(s.isOpen, isFalse);
  });

  testWidgets('permission denied: explanation, then Try again opens it', (
    t,
  ) async {
    final s = _FakeSession([CameraProblem.denied]);
    await open(t, s);
    expect(find.text('Camera access needed'), findsOneWidget);
    expect(find.textContaining('skip'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(s.opens, 2);
    expect(find.byKey(const Key('preview')), findsOneWidget);
  });

  testWidgets('denied permanently: Open settings, no retry loop', (t) async {
    final s = _FakeSession([CameraProblem.deniedForever]);
    await open(t, s);
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('no front camera: says so; Not now returns nothing', (t) async {
    final s = _FakeSession([CameraProblem.noFrontCamera]);
    final result = await open(t, s);
    expect(find.text('No front camera'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(await result.future, isNull);
  });

  testWidgets('background releases the camera; return reopens it', (t) async {
    final s = _FakeSession([]);
    await open(t, s);
    expect(s.isOpen, isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(s.isOpen, isFalse);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(s.isOpen, isTrue);
    expect(s.opens, 2);
    expect(find.byKey(const Key('preview')), findsOneWidget);
  });

  testWidgets('a failed capture keeps the camera and says so', (t) async {
    final s = _FakeSession([])..failCapture = true;
    await open(t, s);
    await t.tap(find.bySemanticsLabel('Take photo'));
    await t.pumpAndSettle();
    expect(find.text("That didn't work. Try again."), findsOneWidget);
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(s.isOpen, isTrue);
  });

  testWidgets('InAppArrivalCamera returns a JPEG photo for the arrival flow', (
    t,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final s = _FakeSession([]);
    await t.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
    final cam = InAppArrivalCamera(() => key.currentState, session: () => s);
    final photo = cam.capture();
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Take photo'));
    await t.pumpAndSettle();
    final got = await photo;
    expect(got?.bytes, _jpeg);
    expect(got?.contentType, 'image/jpeg');
  });
}
