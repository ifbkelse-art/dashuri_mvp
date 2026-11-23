// Dark Mode pass (23 Nov 2026): WCAG 2.2 AA in BOTH themes.
//
// 1. Every foreground role of the ColorScheme and of DashuriColors against
//    the backgrounds it is used on (numbers, not screenshots).
// 2. Representative components rendered in light and dark, then every
//    visible text checked against the colour actually painted behind it
//    (tool/uiux/audit_hook.dart auditContrast; disabled controls exempt).
// 3. Theme switching: light ↔ dark and the system setting update every
//    component, with no stale colours.

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/uiux/audit_hook.dart' show auditContrast, contrastRatio;

const _text = 4.5; // normal text
const _ui = 3.0; // large text, icons, meaningful borders

void main() {
  setUpAll(() => DashuriText.useGoogleFonts = false);

  for (final (name, theme) in [
    ('light', DashuriTheme.light()),
    ('dark', DashuriTheme.dark()),
  ]) {
    group('$name theme', () {
      final s = theme.colorScheme;
      final c = theme.extension<DashuriColors>()!;
      final surfaces = {
        'surface': s.surface,
        'containerLowest': s.surfaceContainerLowest,
        'containerLow': s.surfaceContainerLow,
        'container': s.surfaceContainer,
        'containerHigh': s.surfaceContainerHigh,
        'containerHighest': s.surfaceContainerHighest,
        'inputFill': theme.inputDecorationTheme.fillColor!,
      };

      // Collects every failing pair, so one run shows them all.
      final fails = <String>[];
      void pair(String what, Color fg, Color bg, double min) {
        final r = contrastRatio(fg, bg);
        if (r < min) fails.add('$what: ${r.toStringAsFixed(2)}:1 < $min:1');
      }

      setUp(fails.clear);
      tearDown(() => expect(fails, isEmpty));

      test('has the DashuriColors extension for its brightness', () {
        expect(
          c,
          theme.brightness == Brightness.dark
              ? DashuriColors.dark
              : DashuriColors.light,
        );
      });

      test('on-colours on their roles (text, 4.5:1)', () {
        pair('onPrimary/primary', s.onPrimary, s.primary, _text);
        pair(
          'onPrimaryContainer',
          s.onPrimaryContainer,
          s.primaryContainer,
          _text,
        );
        pair('onSecondary/secondary', s.onSecondary, s.secondary, _text);
        pair(
          'onSecondaryContainer',
          s.onSecondaryContainer,
          s.secondaryContainer,
          _text,
        );
        pair('onTertiary/tertiary', s.onTertiary, s.tertiary, _text);
        pair('onError/error', s.onError, s.error, _text);
        pair('onErrorContainer', s.onErrorContainer, s.errorContainer, _text);
        pair('onInverseSurface', s.onInverseSurface, s.inverseSurface, _text);
      });

      test('text and accents on every surface level', () {
        surfaces.forEach((k, bg) {
          pair('onSurface/$k', s.onSurface, bg, _text);
          pair('onSurfaceVariant/$k', s.onSurfaceVariant, bg, _text);
          pair('primary as text/$k', s.primary, bg, _text);
          pair('error as text/$k', s.error, bg, _text);
          // Gold text is only used on page/card levels, never on the
          // highest container (tracks, placeholders).
          if (k != 'containerHighest') {
            pair('secondary as text/$k', s.secondary, bg, _text);
          }
          pair('tertiary as text/$k', s.tertiary, bg, _text);
          pair('positiveText/$k', c.positiveText, bg, _text);
          pair('outline (borders)/$k', s.outline, bg, _ui);
          pair('onlineDot/$k', c.onlineDot, bg, _ui);
        });
      });

      test('status tones: text 4.5:1 on the tint, icons 3:1', () {
        for (final (k, t) in [
          ('success', c.success),
          ('warning', c.warning),
          ('error', c.error),
          ('info', c.info),
          ('neutral', c.neutral),
        ]) {
          pair('$k onContainer/container', t.onContainer, t.container, _text);
          pair('$k onContainer/surface', t.onContainer, s.surface, _text);
          pair('$k icon/container', t.icon, t.container, _ui);
          pair('$k icon/surface', t.icon, s.surface, _ui);
        }
      });

      test('navigation selected/unselected states', () {
        final nav = s.surfaceContainerLow;
        pair('nav label', s.onSurface, nav, _text);
        pair('nav unselected icon', s.onSurfaceVariant, nav, _ui);
        pair(
          'nav selected icon/indicator',
          s.onSurface,
          s.primaryContainer,
          _ui,
        );
        pair('rail selected label', s.primary, nav, _text);
        // Selected chips: inverse fill with inverse text.
        pair('selected chip', s.onInverseSurface, s.inverseSurface, _text);
      });
    });
  }

  test('fixed hero/media palettes are readable on what they sit on', () {
    for (final bg in [
      DashuriTokens.burgundy600,
      DashuriTokens.burgundy700,
      DashuriTokens.burgundy800,
      DashuriTokens.burgundy900,
      DashuriTokens.burgundy950,
    ]) {
      expect(contrastRatio(DashuriColors.onHero, bg), greaterThan(_text));
      expect(contrastRatio(DashuriColors.onHeroMuted, bg), greaterThan(_text));
    }
    // Over the darkest possible frame and a white frame with the scrim.
    final overWhite = Color.alphaBlend(DashuriColors.mediaScrim, Colors.white);
    expect(contrastRatio(DashuriColors.onMedia, overWhite), greaterThan(_text));
  });

  group('rendered components', () {
    Widget gallery({bool disabled = false}) => Scaffold(
      appBar: AppBar(title: const Text('Title')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chats'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              title: Text('Card title'),
              subtitle: Text('Card subtitle'),
              leading: Icon(Icons.person),
            ),
          ),
          FilledButton(onPressed: () {}, child: const Text('Filled')),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          TextButton(onPressed: () {}, child: const Text('Text button')),
          // Disabled states are exempt from WCAG; they must still render.
          const FilledButton(onPressed: null, child: Text('Disabled')),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Label',
              hintText: 'Placeholder',
              helperText: 'Helper text',
            ),
          ),
          const TextField(decoration: InputDecoration(errorText: 'Error text')),
          Wrap(
            children: [
              ChoiceChip(
                label: const Text('Selected'),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('Unselected'),
                selected: false,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('Filter on'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
          for (final tone in StatusTone.values)
            StatusTag(label: tone.name, tone: tone, dot: true),
          for (final tone in InfoBannerTone.values)
            InfoBanner(message: 'Banner ${tone.name}', tone: tone),
          const SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('Switch'),
          ),
        ],
      ),
    );

    for (final (name, theme) in [
      ('light', DashuriTheme.light()),
      ('dark', DashuriTheme.dark()),
    ]) {
      testWidgets('$name: every visible text meets AA', (t) async {
        t.view
          ..physicalSize = const Size(400, 2400)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(theme: theme, home: gallery()));
        await t.pumpAndSettle();
        expect(auditContrast(t), isEmpty);
      });

      testWidgets('$name: dialog and bottom sheet meet AA', (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Dialog title'),
                          content: const Text('Dialog body text'),
                          actions: [
                            TextButton(
                              onPressed: () {},
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () {},
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('dialog'),
                    ),
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const ListTile(
                          title: Text('Sheet item'),
                          subtitle: Text('Sheet detail'),
                        ),
                      ),
                      child: const Text('sheet'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('dialog'));
        await t.pumpAndSettle();
        expect(auditContrast(t), isEmpty);
        await t.tap(find.text('Cancel'), warnIfMissed: false);
        Navigator.of(t.element(find.text('Dialog title'))).pop();
        await t.pumpAndSettle();
        await t.tap(find.text('sheet'));
        await t.pumpAndSettle();
        expect(find.text('Sheet item'), findsOneWidget);
        expect(auditContrast(t), isEmpty);
      });
    }
  });

  group('theme switching', () {
    Color textColor(WidgetTester t, String s) => t
        .widget<RichText>(
          find.descendant(of: find.text(s), matching: find.byType(RichText)),
        )
        .text
        .style!
        .color!;

    Color tagFill(WidgetTester t) {
      final box = t.widget<Container>(
        find
            .ancestor(of: find.text('Busy'), matching: find.byType(Container))
            .first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    Widget app(ThemeMode mode) => MaterialApp(
      theme: DashuriTheme.light(),
      darkTheme: DashuriTheme.dark(),
      themeMode: mode,
      home: const Scaffold(
        body: Column(
          children: [
            Text('Body'),
            StatusTag(label: 'Busy', tone: StatusTone.busy),
          ],
        ),
      ),
    );

    testWidgets('light → dark → light updates text and tones', (t) async {
      final light = DashuriTheme.light();
      final dark = DashuriTheme.dark();
      await t.pumpWidget(app(ThemeMode.light));
      await t.pumpAndSettle();
      expect(textColor(t, 'Body'), light.colorScheme.onSurface);
      expect(tagFill(t), DashuriColors.light.warning.container);

      await t.pumpWidget(app(ThemeMode.dark));
      await t.pumpAndSettle();
      expect(textColor(t, 'Body'), dark.colorScheme.onSurface);
      expect(tagFill(t), DashuriColors.dark.warning.container);
      expect(auditContrast(t), isEmpty);

      await t.pumpWidget(app(ThemeMode.light));
      await t.pumpAndSettle();
      expect(textColor(t, 'Body'), light.colorScheme.onSurface);
      expect(tagFill(t), DashuriColors.light.warning.container);
    });

    testWidgets('follows the system setting (the app default)', (t) async {
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await t.pumpWidget(app(ThemeMode.system));
      await t.pumpAndSettle();
      expect(tagFill(t), DashuriColors.light.warning.container);

      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await t.pumpAndSettle();
      expect(tagFill(t), DashuriColors.dark.warning.container);
      expect(textColor(t, 'Body'), DashuriTheme.dark().colorScheme.onSurface);
    });

    testWidgets('DashuriColors.of falls back by brightness', (t) async {
      late DashuriColors got;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              got = DashuriColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(got, DashuriColors.dark);
    });
  });
}
