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
//   DASHURI_UIUX_THEME=dark     render with the dark theme (helpers pass
//                               their theme through [uiuxTheme])
//   DASHURI_UIUX_CONTRAST=/p    append every visible text whose colour is
//                               below WCAG AA against the colour actually
//                               painted behind it (see [auditContrast])
//
// Screenshots are rendering checks in the test engine, NOT device testing.
//
// This file is only compiled inside a feature package's tests (relative
// import), where flutter, flutter_test and the design system are available;
// the repo-wide analyzer sees it as part of the root package.
// ignore_for_file: depend_on_referenced_packages, directives_ordering

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// The theme a pump helper should use: [light], or the dark theme when
/// DASHURI_UIUX_THEME=dark.
ThemeData uiuxTheme(ThemeData light) =>
    _env['DASHURI_UIUX_THEME'] == 'dark' ? DashuriTheme.dark() : light;

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
  final contrastLog = _env['DASHURI_UIUX_CONTRAST'];
  if (contrastLog != null) {
    await t.pump(const Duration(milliseconds: 400));
    final found = auditContrast(t);
    if (found.isNotEmpty) {
      File(contrastLog).writeAsStringSync(
        '=== ${t.testDescription}\n${found.join('\n')}\n',
        mode: FileMode.append,
      );
    }
  }
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

// ---------------------------------------------------------------------------
// Contrast audit (Dark Mode pass, 23 Nov 2026).
//
// For every laid-out, visible paragraph: its text colour (first coloured
// span) against the background actually painted behind it. The background
// is found by walking UP the render tree: decorated boxes, coloured boxes,
// Material (physical shapes) and fills drawn by earlier siblings in a
// Stack; translucent layers are alpha-blended over what is below them.
// Text drawn over images, video or gradients is reported against every
// gradient stop (worst case) and skipped over images/video, which need a
// scrim and are checked by eye. Disabled controls are exempt from WCAG and
// are skipped when Flutter marks them disabled in semantics.
// ---------------------------------------------------------------------------

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

/// WCAG 2.x contrast ratio of two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _over(Color top, Color below) => Color.alphaBlend(top, below);

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// A fill painted by [r] itself: (colours, isMedia). Gradients return all
/// stops; images/video return isMedia.
(List<Color>, bool)? _fillOf(RenderObject r) {
  if (r is RenderDecoratedBox && r.position == DecorationPosition.background) {
    final d = r.decoration;
    if (d is BoxDecoration) {
      if (d.image != null) return (const [], true);
      if (d.gradient != null) return (d.gradient!.colors, false);
      if (d.color != null) return ([d.color!], false);
    } else if (d is ShapeDecoration) {
      if (d.image != null) return (const [], true);
      if (d.gradient != null) return (d.gradient!.colors, false);
      if (d.color != null) return ([d.color!], false);
    }
  }
  if (r is RenderPhysicalShape) return ([r.color], false);
  if (r is RenderPhysicalModel) return ([r.color], false);
  if (r is RenderImage || r is TextureBox || r is PlatformViewRenderBox) {
    return (const [], true);
  }
  final creator = r.debugCreator;
  if (creator is DebugCreator) {
    final w = creator.element.widget;
    if (w is ColoredBox) return ([w.color], false);
  }
  return null;
}

/// The fill of a Stack child painted behind our branch, if it is a
/// full-bleed layer: descends through single-child wrappers only.
(List<Color>, bool)? _layerFill(RenderObject child) {
  RenderObject? r = child;
  for (var depth = 0; r != null && depth < 12; depth++) {
    final f = _fillOf(r);
    if (f != null) return f;
    RenderObject? only;
    var n = 0;
    r.visitChildren((c) {
      only = c;
      n++;
    });
    if (n != 1) return null;
    r = only;
  }
  return null;
}

bool _covers(RenderObject layer, RenderBox target) {
  if (layer is! RenderBox || !layer.hasSize) return false;
  try {
    final a = MatrixUtils.transformRect(
      layer.getTransformTo(null),
      Offset.zero & layer.size,
    );
    final b = MatrixUtils.transformRect(
      target.getTransformTo(null),
      Offset.zero & target.size,
    );
    return a.inflate(0.5).contains(b.topLeft) &&
        a.inflate(0.5).contains(b.bottomRight);
  } catch (_) {
    return false;
  }
}

/// Background colour candidates behind [p] (worst case decides), or null
/// over media.
List<Color>? _backgroundOf(
  RenderParagraph p,
  Color canvas,
  Map<RenderObject, List<Color>> extra,
) {
  final layers = <List<Color>>[];
  RenderObject child = p;
  RenderObject? r = p.parent;
  while (r != null) {
    final ex = extra[r];
    if (ex != null) {
      layers.add(ex);
      if (ex.every((c) => c.a >= 0.99)) break;
    }
    final own = _fillOf(r);
    if (own != null) {
      if (own.$2) return null;
      layers.add(own.$1);
      if (own.$1.every((c) => c.a >= 0.99)) break;
    }
    if (r is RenderStack) {
      // Siblings painted before our branch, nearest first.
      final before = <RenderObject>[];
      var reached = false;
      r.visitChildren((c) {
        if (identical(c, child)) reached = true;
        if (!reached) before.add(c);
      });
      var opaque = false;
      for (final s in before.reversed) {
        final f = _layerFill(s);
        if (f == null || !_covers(s, p)) continue;
        if (f.$2) return null;
        layers.add(f.$1);
        if (f.$1.every((c) => c.a >= 0.99)) {
          opaque = true;
          break;
        }
      }
      if (opaque) break;
    }
    child = r;
    r = r.parent;
  }
  // Compose from the bottom (canvas) up, per gradient stop.
  var results = <Color>[canvas];
  for (final layer in layers.reversed) {
    results = [
      for (final below in results)
        for (final c in layer) _over(c, below),
    ];
  }
  return results;
}

Color? _textColor(InlineSpan span) {
  Color? found;
  span.visitChildren((s) {
    final c = s.style?.color ?? s.style?.foreground?.color;
    if (c != null && s is TextSpan && (s.text?.trim().isNotEmpty ?? false)) {
      found = c;
      return false;
    }
    return true;
  });
  return found ?? span.style?.color;
}

bool _visible(RenderObject p) {
  for (RenderObject? r = p; r != null; r = r.parent) {
    if (r is RenderOpacity && r.opacity < 0.05) return false;
    if (r is RenderAnimatedOpacity && r.opacity.value < 0.05) return false;
    if (r is RenderOffstage && r.offstage) return false;
    if (r is RenderBox && r.hasSize && r.size.isEmpty) return false;
  }
  return true;
}

/// Element-level facts render objects don't carry: fills painted on a
/// parent Material (Ink, chips) keyed by the render object they sit
/// under, and whether the text is part of a disabled control (WCAG
/// exempts those).
({Map<RenderObject, List<Color>> extra, bool disabled}) _elementFacts(
  RenderParagraph p,
) {
  final extra = <RenderObject, List<Color>>{};
  var disabled = false;
  final c = p.debugCreator;
  if (c is! DebugCreator) return (extra: extra, disabled: false);
  void consider(Element e) {
    final w = e.widget;
    if (w is ButtonStyleButton && !w.enabled) disabled = true;
    if (w is IconButton && w.onPressed == null) disabled = true;
    if (w is TextField && w.enabled == false) disabled = true;
    if (w is ListTile && !w.enabled) disabled = true;
    if (w is SwitchListTile && w.onChanged == null) disabled = true;
    if (w is CheckboxListTile && w.onChanged == null) disabled = true;
    if (w is RawChip && !w.isEnabled) disabled = true;
    final ro = e.renderObject;
    if (ro == null) return;
    if (w is Ink) {
      final d = w.decoration;
      if (d is BoxDecoration) {
        if (d.gradient != null) extra[ro] = d.gradient!.colors;
        if (d.color != null) extra[ro] = [d.color!];
      }
    }
    if (w is RawChip) {
      final theme = ChipTheme.of(e);
      final fill = w.selected
          ? (w.selectedColor ?? theme.selectedColor)
          : (w.backgroundColor ?? theme.backgroundColor);
      // The fill is painted by the chip's render box, inside the chip's
      // own Material: key it there, below that Material's canvas colour.
      RenderObject? box = p.parent;
      while (box != null &&
          !box.runtimeType.toString().contains('RenderChip') &&
          !identical(box, ro)) {
        box = box.parent;
      }
      if (fill != null) extra[box ?? ro] = [fill];
    }
  }

  consider(c.element);
  c.element.visitAncestorElements((e) {
    consider(e);
    return true;
  });
  return (extra: extra, disabled: disabled);
}

String _where(RenderParagraph p) {
  final names = <String>[];
  for (RenderObject? r = p; r != null && names.length < 7; r = r.parent) {
    final c = r.debugCreator;
    if (c is! DebugCreator) continue;
    final n = c.element.widget.runtimeType.toString();
    if (n.startsWith('_') ||
        const {
          'RichText',
          'Text',
          'DefaultTextStyle',
          'Semantics',
          'MergeSemantics',
          'Padding',
          'Align',
          'Center',
          'SizedBox',
          'ConstrainedBox',
          'Flexible',
          'Expanded',
          'Row',
          'Column',
          'Flex',
          'LimitedBox',
          'Builder',
          'DecoratedBox',
          'ColoredBox',
          'Container',
          'IconTheme',
          'Listener',
          'MouseRegion',
          'RepaintBoundary',
          'Positioned',
          'Stack',
        }.contains(n)) {
      continue;
    }
    if (!names.contains(n)) names.add(n);
  }
  return names.join(' < ');
}

/// Visible text below WCAG AA on the current screen (one line each).
List<String> auditContrast(WidgetTester t) {
  final out = <String>{};
  final ctx = t.binding.rootElement;
  if (ctx == null) return const [];
  Color canvas = Colors.white;
  ctx.visitChildElements((e) {
    final theme = e.findAncestorWidgetOfExactType<Theme>();
    if (theme != null) canvas = theme.data.colorScheme.surface;
  });
  void visit(RenderObject r) {
    final facts = r is RenderParagraph ? _elementFacts(r) : null;
    if (r is RenderParagraph && r.hasSize && _visible(r) && !facts!.disabled) {
      final text = r.text.toPlainText().trim();
      final fg = _textColor(r.text);
      if (text.isNotEmpty && fg != null && fg.a > 0.05) {
        final bgs = _backgroundOf(r, canvas, facts.extra);
        if (bgs != null) {
          final style = r.text.style;
          final size = (style?.fontSize ?? 14) * r.textScaler.scale(1);
          final bold = (style?.fontWeight?.value ?? 400) >= 700;
          final large = size >= 24 || (bold && size >= 18.66);
          // Icons are graphics (WCAG 1.4.11): 3:1.
          final icon = (style?.fontFamily ?? '').contains('Icons');
          final need = large || icon ? 3.0 : 4.5;
          for (final bg in bgs) {
            final ratio = contrastRatio(_over(fg, bg), bg);
            if (ratio < need) {
              final snippet = icon
                  ? 'icon U+${text.runes.first.toRadixString(16)}'
                  : (text.length > 40 ? '${text.substring(0, 40)}…' : text);
              out.add(
                '  ${ratio.toStringAsFixed(2)}:1 (need $need) '
                'fg ${_hex(_over(fg, bg))} bg ${_hex(bg)} "$snippet"  [${_where(r)}]',
              );
              break;
            }
          }
        }
      }
    }
    r.visitChildren(visit);
  }

  for (final view in t.binding.renderViews) {
    view.visitChildren(visit);
  }
  return out.toList();
}
