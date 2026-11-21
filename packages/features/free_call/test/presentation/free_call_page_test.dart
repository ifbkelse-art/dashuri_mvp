import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_free_call/feature_free_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Card extends MockCubit<FreeCallCardState> implements FreeCallCardCubit {}

class _Match extends MockCubit<FreeCallMatchState>
    implements FreeCallMatchCubit {}

Widget _echo(BuildContext _, GoRouterState s) =>
    Scaffold(body: Text('route:${s.uri}'));

void main() {
  const sizes = {'phone': Size(360, 640), 'tablet': Size(1024, 768)};

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      Future<(_Card, _Match)> pump(
        WidgetTester t,
        FreeCallCardState card, {
        FreeCallMatchState match = const FreeCallMatchIdle(),
        Stream<FreeCallMatchState>? matchStream,
      }) async {
        DashuriText.useGoogleFonts = false;
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final c = _Card(), m = _Match();
        when(() => c.state).thenReturn(card);
        when(c.load).thenAnswer((_) async {});
        when(m.start).thenAnswer((_) async {});
        if (matchStream != null) {
          whenListen(m, matchStream, initialState: match);
        } else {
          when(() => m.state).thenReturn(match);
        }
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<FreeCallCardCubit>.value(value: c),
                  BlocProvider<FreeCallMatchCubit>.value(value: m),
                ],
                child: const FreeCallPage(),
              ),
            ),
            GoRoute(
              path: '/:a',
              builder: _echo,
              routes: [GoRoute(path: ':b', builder: _echo)],
            ),
          ],
        );
        addTearDown(router.dispose);
        await t.pumpWidget(MaterialApp.router(routerConfig: router));
        await t.pump();
        return (c, m);
      }

      testWidgets('C10 searching with cancel', (t) async {
        final (_, m) = await pump(
          t,
          const FreeCallCardStateLoaded(
            FreeCallCard(status: 'available', usedAt: null),
          ),
          match: const FreeCallMatchSearching(),
        );
        expect(find.text('Finding someone for you…'), findsOneWidget);
        await t.tap(find.text('Cancel'));
        verify(m.cancel).called(1);
      });

      testWidgets('match opens the call screen', (t) async {
        await pump(
          t,
          const FreeCallCardStateLoaded(
            FreeCallCard(status: 'available', usedAt: null),
          ),
          match: const FreeCallMatchSearching(),
          matchStream: Stream.value(const FreeCallMatchFound('c9')),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text('route:/calls/c9'), findsOneWidget);
      });

      testWidgets('used card', (t) async {
        await pump(
          t,
          const FreeCallCardStateLoaded(
            FreeCallCard(status: 'used', usedAt: null),
          ),
        );
        expect(find.text('Free Call Card used'), findsOneWidget);
        expect(find.text('Buy Diamonds'), findsOneWidget);
      });

      testWidgets('no host available offers retry', (t) async {
        final (_, m) = await pump(
          t,
          const FreeCallCardStateLoaded(
            FreeCallCard(status: 'available', usedAt: null),
          ),
          match: const FreeCallMatchNoHost(),
        );
        await t.tap(find.text('Try again'));
        verify(m.start).called(1);
      });

      testWidgets('integrity failure message', (t) async {
        await pump(
          t,
          const FreeCallCardStateLoaded(
            FreeCallCard(status: 'available', usedAt: null),
          ),
          match: const FreeCallMatchFailed(
            PlatformFailure(code: 'integrity_unavailable'),
          ),
        );
        expect(find.textContaining('Google Play'), findsOneWidget);
      });

      testWidgets('card error retries', (t) async {
        final (c, _) = await pump(
          t,
          const FreeCallCardStateFailed(NetworkFailure()),
        );
        await t.tap(find.text('Try again'));
        verify(c.load).called(1);
      });

      testWidgets('iOS shows unavailable', (t) async {
        DashuriText.useGoogleFonts = false;
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          const MaterialApp(home: FreeCallPage(supported: false)),
        );
        expect(find.text('Free calls are Android only'), findsOneWidget);
      });
    });
  }
}
