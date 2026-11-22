// UI/UX pass (22 Nov 2026) — opt-in audit hook for widget tests.
//
// Every feature package's pump helper calls [uiuxBeforePump] and
// [uiuxAfterPump]. With no environment variables set they do nothing, so
// normal test runs are unchanged. Imported by relative path (test-only).
//
//   DASHURI_UIUX_SIZE=320x568   force this logical window size
//   DASHURI_UIUX_SCALE=2.0      force this text scale (helpers apply it)
//   DASHURI_UIUX_LOG=/path.log  append every FlutterError (with the widget
//                               creation location) — also ones a test
//                               swallows with takeException()
//   DASHURI_UIUX_SHOTS=/dir     save a PNG of each pumped screen, rendered
//                               with real fonts (Roboto, Material Icons,
//                               a serif for display text)
//   DASHURI_UIUX_KEYBOARD=0.4   open a software keyboard covering that
//                               fraction of the window (bottom inset
//                               consumed, as on devices)
//   DASHURI_UIUX_FONTS=1        use those real fonts without screenshots
//                               (the test font draws every glyph as a 1 em
//                               square, overstating text widths ~1.6x)
//
// Screenshots are rendering checks in the test engine, NOT device testing.
//
// This file is only compiled inside a feature package's tests (relative
// import), where flutter, flutter_test and the design system are available;
// the repo-wide analyzer sees it as part of the root package.
// ignore_for_file: depend_on_referenced_packages, directives_ordering

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, String> _env = Platform.environment;

bool get uiuxActive => _env.keys.any((k) => k.startsWith('DASHURI_UIUX_'));

/// The forced window size, or [fallback].
Size uiuxSize(Size fallback) {
  final v = _env['DASHURI_UIUX_SIZE'];
  if (v == null) return fallback;
  final p = v.split('x').map(double.parse).toList();
  return Size(p[0], p[1]);
}

/// The forced text scale, or [fallback].
double uiuxScale(double fallback) =>
    double.tryParse(_env['DASHURI_UIUX_SCALE'] ?? '') ?? fallback;

bool _fontsLoaded = false;

Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final flutterRoot =
      _env['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f.startsWith('/') ? f : '$dir/$f');
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }

  const roboto = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ];
  await load('Roboto', roboto);
  // Styles without a fontFamily fall back to the test engine's block font
  // ('FlutterTest'); give that family real glyphs too.
  await load('FlutterTest', roboto);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  await load('serif', [
    '/System/Library/Fonts/Supplemental/Georgia.ttf',
    'Roboto-Regular.ttf',
  ]);
}

/// Call at the start of a pump helper, after setting the window size.
Future<void> uiuxBeforePump(WidgetTester t) async {
  if (!uiuxActive) return;
  if (_env['DASHURI_UIUX_SIZE'] != null) {
    final s = uiuxSize(Size.zero);
    t.view
      ..physicalSize = s
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 47, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    final kb = double.tryParse(_env['DASHURI_UIUX_KEYBOARD'] ?? '');
    if (kb != null && kb > 0) {
      t.view
        ..viewInsets = FakeViewPadding(bottom: s.height * kb)
        ..padding = const FakeViewPadding(top: 47);
    }
  }
  final log = _env['DASHURI_UIUX_LOG'];
  if (log != null) {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      File(log).writeAsStringSync(
        '=== ${t.testDescription}\n${details.toString()}\n',
        mode: FileMode.append,
      );
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }
  if (_env['DASHURI_UIUX_SHOTS'] != null ||
      _env['DASHURI_UIUX_FONTS'] != null) {
    await t.runAsync(_loadFonts);
    DashuriText.testFontFamily = 'Roboto';
    addTearDown(() => DashuriText.testFontFamily = null);
  }
}

int _shot = 0;

/// Call after the helper's first pump. Saves a screenshot when enabled.
Future<void> uiuxAfterPump(WidgetTester t) async {
  final dir = _env['DASHURI_UIUX_SHOTS'];
  if (dir == null) return;
  await t.pump(
    const Duration(milliseconds: 400),
  ); // let images/animations settle
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final size = view.size;
  final name = t.testDescription
      .replaceAll(RegExp(r'[^A-Za-z0-9×@.]+'), '_')
      .replaceAll(RegExp('_+'), '_');
  final file = File('$dir/${(++_shot).toString().padLeft(3, '0')}_$name.png');
  await t.runAsync(() async {
    final image = await layer.toImage(Offset.zero & size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  debugPrint('uiux shot: ${file.path}');
}
