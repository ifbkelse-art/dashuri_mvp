import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// EXPERIMENT responsiveness audit (P0). Viewports from the requirement,
/// plus a landscape phone.
const auditSizes = <String, Size>{
  '320x568': Size(320, 568),
  '360x800': Size(360, 800),
  '390x844': Size(390, 844),
  '412x915': Size(412, 915),
  'tablet 1024x1366': Size(1024, 1366),
  'landscape 844x390': Size(844, 390),
};

const auditTextScales = [1.0, 1.3, 2.0];

/// Status bar / home indicator insets similar to a notched phone.
const notchPadding = FakeViewPadding(top: 47, bottom: 34);

/// Sets the test window: [size] logical px, notch insets, optional keyboard.
void setWindow(WidgetTester t, Size size, {double keyboard = 0}) {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = notchPadding
    ..viewPadding = notchPadding
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  if (keyboard > 0) setKeyboard(t, keyboard);
}

/// Opens (or with 0 closes) the software keyboard. Like the platforms, the
/// bottom safe-area padding is consumed while the keyboard is up (only
/// viewPadding keeps it).
void setKeyboard(WidgetTester t, double height) {
  t.view
    ..viewInsets = FakeViewPadding(bottom: height)
    ..padding = height > 0
        ? FakeViewPadding(top: notchPadding.top)
        : notchPadding;
}

/// Every visible text stays inside the window horizontally (no clipped or
/// off-screen text, no horizontal overflow). Layout exceptions such as
/// RenderFlex overflow fail the test on their own.
void expectTextInsideWindow(WidgetTester t, {double tolerance = .5}) {
  final width = t.view.physicalSize.width / t.view.devicePixelRatio;
  for (final e in find.byType(RichText).evaluate()) {
    final box = e.renderObject! as RenderBox;
    if (!box.hasSize || !box.attached) continue;
    final r = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    expect(
      r.left >= -tolerance && r.right <= width + tolerance,
      isTrue,
      reason:
          'text "${(e.widget as RichText).text.toPlainText()}" at $r '
          'is outside the ${width}px window',
    );
  }
}

/// [finder] is fully on screen and above the keyboard.
void expectReachable(WidgetTester t, Finder finder, {String? reason}) {
  final size = t.view.physicalSize / t.view.devicePixelRatio;
  final keyboard = t.view.viewInsets.bottom / t.view.devicePixelRatio;
  final r = t.getRect(finder);
  expect(
    r.left >= -.5 &&
        r.top >= -.5 &&
        r.right <= size.width + .5 &&
        r.bottom <= size.height - keyboard + .5,
    isTrue,
    reason:
        '${reason ?? finder} at $r is not reachable in $size '
        '(keyboard $keyboard)',
  );
}
