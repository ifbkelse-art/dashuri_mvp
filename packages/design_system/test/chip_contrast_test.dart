// UI/UX pass: selected chips must stay readable for every chip type.
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, chip) in [
    (
      'FilterChip',
      FilterChip(
        label: const Text('Hindi'),
        selected: true,
        onSelected: (_) {},
      ),
    ),
    (
      'ChoiceChip',
      ChoiceChip(
        label: const Text('Hindi'),
        selected: true,
        onSelected: (_) {},
      ),
    ),
  ]) {
    testWidgets('selected $name label contrasts with its fill', (t) async {
      DashuriText.useGoogleFonts = false;
      final theme = DashuriTheme.light();
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: Center(child: chip)),
        ),
      );
      // The colour actually painted: root style or the first span's.
      final p = t.renderObject<RenderParagraph>(find.text('Hindi'));
      Color? fg = p.text.style?.color;
      p.text.visitChildren((span) {
        fg ??= span.style?.color;
        return fg == null;
      });
      final bg = theme.colorScheme.inverseSurface;
      double lum(Color c) => c.computeLuminance();
      final ratio =
          (lum(fg!) > lum(bg) ? lum(fg!) + .05 : lum(bg) + .05) /
          (lum(fg!) > lum(bg) ? lum(bg) + .05 : lum(fg!) + .05);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$fg on $bg');
    });
  }

  // Every InfoBanner tone is readable (>= 4.5:1), and info is not error.
  double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
  }

  for (final (tone, bg, fg) in [
    ('info', DashuriTokens.info100, DashuriTokens.info),
    ('warning', DashuriTokens.warning100, DashuriTokens.warningText),
    ('error', DashuriTokens.error100, DashuriTokens.error),
    ('success', DashuriTokens.success100, DashuriTokens.successText),
  ]) {
    test('InfoBanner $tone text contrast', () {
      expect(ratio(fg, bg), greaterThanOrEqualTo(4.5), reason: tone);
    });
  }
}
