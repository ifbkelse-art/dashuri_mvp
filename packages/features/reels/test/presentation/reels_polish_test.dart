// Reels UI completion pass (23 Nov 2026): long captions, block from a
// reel, and readable overlays in light and dark themes.

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../tool/uiux/audit_hook.dart' show auditContrast;
import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

class _Feed extends MockCubit<ReelsFeedState> implements ReelsFeedCubit {}

Widget _page(ReelsFeedCubit c) =>
    BlocProvider<ReelsFeedCubit>.value(value: c, child: const ReelsFeedPage());

final _long = List.filled(
  12,
  'A long caption about tonight and the music we love.',
).join(' ');

void main() {
  // Before any theme is built (themes are built while declaring tests).
  DashuriText.useGoogleFonts = false;
  setUpAll(() {
    registerFallbackValue(ReelReportCategory.other);
    registerFallbackValue(FeedTab.forYou);
  });

  late _Feed c;
  setUp(() {
    c = _Feed();
    when(() => c.load(any())).thenAnswer((_) async {});
    when(() => c.loadMore()).thenAnswer((_) async {});
    when(() => c.flush()).thenAnswer((_) async {});
  });

  testResponsive('a long caption is clipped to 3 lines and expands', (
    t,
    size,
    scale,
  ) async {
    when(() => c.state).thenReturn(
      ReelsFeedLoaded(
        FeedTab.forYou,
        items: [
          reel(
            'L',
            caption: _long,
            by: creator('h', host: host),
          ),
        ],
        nextCursor: null,
      ),
    );
    await pumpPage(t, _page(c), size: size, textScale: scale);
    expect(t.takeException(), isNull);
    expect(find.text('more'), findsOneWidget);
    final clipped = t.widget<Text>(find.text(_long));
    expect(clipped.maxLines, 3);

    // Scroll only the info panel (ensureVisible would also nudge the
    // vertical PageView).
    final info = find
        .descendant(
          of: find.byType(ReelView),
          matching: find.byType(Scrollable),
        )
        .first;
    await t.scrollUntilVisible(find.text('more'), 40, scrollable: info);
    await t.tap(find.text('more'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(t.widget<Text>(find.text(_long)).maxLines, isNull);
    expect(find.text('less'), findsOneWidget);
    // Actions stay reachable with the caption open.
    expect(find.byTooltip('Like').hitTestable(), findsOneWidget);
  });

  testWidgets('a short caption has no "more"', (t) async {
    when(() => c.state).thenReturn(
      ReelsFeedLoaded(FeedTab.forYou, items: [reel('s')], nextCursor: null),
    );
    await pumpPage(t, _page(c));
    expect(find.text('Caption s'), findsOneWidget);
    expect(find.text('more'), findsNothing);
  });

  testWidgets('the report sheet can be closed without choosing anything', (
    t,
  ) async {
    when(() => c.state).thenReturn(
      ReelsFeedLoaded(FeedTab.forYou, items: [reel('x')], nextCursor: null),
    );
    await pumpPage(t, _page(c));
    await t.tap(find.byTooltip('Report or block'));
    await t.pumpAndSettle();
    expect(find.text('Report this reel'), findsOneWidget);
    // A visible, reachable close control (plus the drag handle).
    expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text('Report this reel'), findsNothing);
    verifyNever(() => c.report(any(), any()));
  });

  for (final confirmed in [true, false]) {
    testWidgets(
      'block from a reel: ${confirmed ? 'confirmed → the creator\'s '
                'reels leave the feed' : 'cancelled → nothing changes'}',
      (t) async {
        when(() => c.state).thenReturn(
          ReelsFeedLoaded(FeedTab.forYou, items: [reel('b')], nextCursor: null),
        );
        final router = await pumpPage(t, _page(c));
        await t.tap(find.byTooltip('Report or block'));
        await t.pumpAndSettle();
        await tapVisible(t, find.text('Block Creator c-b'));
        await t.pumpAndSettle();
        // The existing safety flow (S06) opens in block mode.
        expect(find.textContaining('mode=block'), findsOneWidget);
        router.pop(confirmed); // the safety page pops true after the block
        await t.pumpAndSettle();
        if (confirmed) {
          verify(() => c.creatorBlocked('c-b', 'Creator c-b')).called(1);
        } else {
          verifyNever(() => c.creatorBlocked(any(), any()));
        }
      },
    );
  }

  for (final (name, theme) in [
    ('light', DashuriTheme.light),
    ('dark', DashuriTheme.dark),
  ]) {
    testWidgets('$name theme: feed overlay, empty and error states meet AA', (
      t,
    ) async {
      DashuriText.useGoogleFonts = false;
      Future<void> show(ReelsFeedState s) async {
        when(() => c.state).thenReturn(s);
        await t.pumpWidget(MaterialApp(theme: theme(), home: _page(c)));
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        expect(auditContrast(t), isEmpty, reason: s.runtimeType.toString());
      }

      await show(
        ReelsFeedLoaded(
          FeedTab.forYou,
          items: [
            reel('a', by: creator('h', host: host)),
            reel('b'),
          ],
          nextCursor: null,
        ),
      );
      await show(
        const ReelsFeedLoaded(FeedTab.following, items: [], nextCursor: null),
      );
      await show(const ReelsFeedFailed(FeedTab.forYou, NetworkFailure()));
    });
  }
}
