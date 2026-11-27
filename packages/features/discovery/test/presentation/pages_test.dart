import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:feature_discovery/src/presentation/widgets/discovery_widgets.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _Grid extends MockCubit<DiscoveryState> implements DiscoveryCubit {}

class _Header extends MockCubit<DiscoveryHeaderState>
    implements DiscoveryHeaderCubit {}

class _Profile extends MockCubit<HostProfileState>
    implements HostProfileCubit {}

void main() {
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      group('DiscoveryPage', () {
        Future<_Grid> pump(
          WidgetTester t,
          DiscoveryState s, {
          DiscoveryHeaderState header = const DiscoveryHeaderState(
            home: DiscoveryHome(
              displayName: 'Arjun',
              availableDiamonds: 12480,
              onlineCount: 128,
            ),
            loading: false,
          ),
        }) async {
          final g = _Grid(), h = _Header();
          when(() => g.state).thenReturn(s);
          when(() => h.state).thenReturn(header);
          when(g.load).thenAnswer((_) async {});
          when(g.loadMore).thenAnswer((_) async {});
          when(g.refresh).thenAnswer((_) async {});
          when(g.clearFilters).thenAnswer((_) async {});
          when(() => g.setLanguage(any())).thenAnswer((_) async {});
          await pumpPage(
            t,
            MultiBlocProvider(
              providers: [
                BlocProvider<DiscoveryCubit>.value(value: g),
                BlocProvider<DiscoveryHeaderCubit>.value(value: h),
              ],
              child: DiscoveryPage(now: DateTime(2026, 11, 21, 19)),
            ),
            size: size,
          );
          return g;
        }

        // Phase 9 accessibility: Android tap-target size and a label on
        // every tappable element.
        testWidgets('C01 meets tap-target and label guidelines', (t) async {
          final handle = t.ensureSemantics();
          await pump(
            t,
            DiscoveryStateLoaded(Page(items: [host('a'), host('b')])),
          );
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });

        testWidgets('C01 header, chips and grid', (t) async {
          final g = await pump(
            t,
            DiscoveryStateLoaded(
              Page(
                items: [
                  host('a'),
                  host('b', availability: 'busy'),
                ],
              ),
            ),
          );
          expect(find.text('Good evening, Arjun'), findsOneWidget);
          expect(find.text('12,480'), findsOneWidget);
          expect(
            find.textContaining('128', findRichText: true),
            findsOneWidget,
          );
          expect(find.text('Host a, 24'), findsOneWidget);
          expect(find.text('In a call'), findsOneWidget);
          await t.tap(find.text('Hindi'));
          verify(() => g.setLanguage('hi')).called(1);
          await t.tap(find.text('Host a, 24'), warnIfMissed: false);
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text('route:/hosts/a'), findsOneWidget);
        });

        testWidgets('grid columns adapt to the width', (t) async {
          await pump(
            t,
            DiscoveryStateLoaded(
              Page(items: [for (var i = 0; i < 6; i++) host('$i')]),
            ),
          );
          final grid = t.widget<SliverGrid>(find.byType(SliverGrid));
          final cols =
              (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                  .crossAxisCount;
          expect(cols, size.width < 600 ? 2 : greaterThanOrEqualTo(3));
        });

        testWidgets('balance pill opens Buy Diamonds', (t) async {
          await pump(t, const DiscoveryStateLoaded(Page(items: [])));
          await t.tap(find.text('12,480'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text('route:/wallet/buy'), findsOneWidget);
        });

        testWidgets('C02 free call banner', (t) async {
          await pump(
            t,
            const DiscoveryStateLoaded(Page(items: [])),
            header: const DiscoveryHeaderState(
              home: DiscoveryHome(
                availableDiamonds: 0,
                freeCallAvailable: true,
              ),
              loading: false,
            ),
          );
          expect(find.text('Your first minute is on us'), findsOneWidget);
          await t.tap(find.text('Start free call'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text('route:/free-call'), findsOneWidget);
        });

        testWidgets('C04 no hosts', (t) async {
          await pump(t, const DiscoveryStateLoaded(Page(items: [])));
          await t.scrollUntilVisible(
            find.text("It's quiet right now"),
            200,
            scrollable: _vertical,
          );
          expect(find.text("It's quiet right now"), findsOneWidget);
        });

        testWidgets('C05 no filter results', (t) async {
          final g = await pump(
            t,
            const DiscoveryStateLoaded(
              Page(items: []),
              DiscoveryFilter(language: 'pa'),
            ),
          );
          await t.scrollUntilVisible(
            find.text('Clear all filters'),
            200,
            scrollable: _vertical,
          );
          await t.drag(_vertical, const Offset(0, -200));
          await t.pump();
          await t.tap(find.text('Clear all filters'));
          verify(g.clearFilters).called(1);
        });

        testWidgets('C06 skeleton', (t) async {
          await pump(t, const DiscoveryStateLoading());
          expect(find.byType(HostCardSkeleton), findsWidgets);
        });

        testWidgets('error offers retry', (t) async {
          final g = await pump(t, const DiscoveryStateFailed(NetworkFailure()));
          await t.scrollUntilVisible(
            find.text('Try again'),
            200,
            scrollable: _vertical,
          );
          expect(find.text("Couldn't load hosts"), findsOneWidget);
          // The 48-pt sort target (Phase 9) made the header taller: bring
          // the button fully on screen (scrollUntilVisible stops at its edge).
          await t.ensureVisible(find.text('Try again'));
          await t.pumpAndSettle();
          await t.tap(find.text('Try again'));
          verify(g.load).called(1);
        });
      });

      group('DiscoveryFiltersPage', () {
        testWidgets('C03 selects and returns a filter', (t) async {
          await pumpPage(
            t,
            const DiscoveryFiltersPage(
              initial: DiscoveryFilter(language: 'hi'),
            ),
            size: size,
          );
          expect(find.text('Filters'), findsOneWidget);
          await t.tap(find.text('Tamil'));
          await t.pump();
          final tamil = t.widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Tamil'),
          );
          expect(tamil.selected, isTrue);
          await t.scrollUntilVisible(
            find.text('Rate: low to high'),
            200,
            scrollable: _vertical,
          );
          await t.tap(find.text('Rate: low to high'));
          await t.pump();
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
          await t.tap(find.text('Reset'));
          await t.pump();
          expect(
            t
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Any'))
                .selected,
            isTrue,
          );
        });
      });

      group('HostProfilePage', () {
        Future<void> pump(WidgetTester t, HostProfileState s) async {
          final c = _Profile();
          when(() => c.state).thenReturn(s);
          when(() => c.load(any())).thenAnswer((_) async {});
          await pumpPage(
            t,
            BlocProvider<HostProfileCubit>.value(
              value: c,
              child: const HostProfilePage(userId: 'a'),
            ),
            size: size,
          );
        }

        HostProfileLoaded loaded(String availability) => HostProfileLoaded((
          profile: HostProfile(
            card: host('a', availability: availability),
            bio: 'Chai over coffee',
          ),
          balance: 12480,
          approxPaisePerDiamondMilli: 2200,
        ));

        testWidgets('C07 meets tap-target and label guidelines', (t) async {
          final handle = t.ensureSemantics();
          await pump(t, loaded('available'));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });

        testWidgets('C07 online: call goes to pre-call', (t) async {
          await pump(t, loaded('available'));
          expect(find.text('Online now'), findsOneWidget);
          expect(find.textContaining('≈ ₹52.80/min'), findsOneWidget);
          expect(
            find.textContaining('about 5 min of talk time'),
            findsOneWidget,
          );
          // Phase 9: the button carries the server rate.
          expect(find.text('Video call · 2,400 / min'), findsOneWidget);
          await t.tap(find.textContaining('Video call'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text('route:/hosts/a/call'), findsOneWidget);
        });

        testWidgets('C08 busy disables calling', (t) async {
          await pump(t, loaded('busy'));
          expect(find.text('In a call. Try again soon'), findsOneWidget);
        });

        testWidgets('C09 offline', (t) async {
          await pump(t, loaded('offline'));
          expect(find.text('Not available right now'), findsOneWidget);
          expect(find.text('Offline'), findsOneWidget);
        });

        testWidgets('message opens a new conversation', (t) async {
          await pump(t, loaded('available'));
          await t.tap(find.byTooltip('Message'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text('route:/messages/new?peerUserId=a'), findsOneWidget);
        });

        testWidgets('C12 actions: block uses the report route', (t) async {
          await pump(t, loaded('available'));
          await t.tap(find.byTooltip('More actions'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text('Report Host a'), findsOneWidget);
          await t.tap(find.text('Block Host a'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(
            find.text('route:/report?userId=a&name=Host+a&mode=block'),
            findsOneWidget,
          );
        });

        testWidgets('error', (t) async {
          await pump(t, const HostProfileFailed(NotFoundFailure()));
          expect(
            find.text('This profile is no longer available.'),
            findsOneWidget,
          );
          expect(find.text('Profile not available'), findsOneWidget);
          expect(find.text('Try again'), findsNothing);
        });

        testWidgets('a network error can be retried', (t) async {
          await pump(t, const HostProfileFailed(NetworkFailure()));
          expect(find.text("Couldn't load this profile"), findsOneWidget);
          expect(find.text('Try again'), findsOneWidget);
        });
      });
    });
  }
}

final _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
