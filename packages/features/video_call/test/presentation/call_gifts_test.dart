// Virtual gifts on the call screen (2026-11-26): the Gift control replaces
// the camera on/off control for the customer only, fits every audit size,
// opens the sheet, and celebrations never block the call controls.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';
import '../layout_audit.dart';

class _Call extends MockBloc<CallBlocEvent, CallState> implements CallBloc {}

class _Catalogue extends Mock implements GetGiftCatalogue {}

class _Balance extends Mock implements GetGiftBalance {}

class _Send extends Mock implements SendGift {}

class _History extends Mock implements GetCallGifts {}

class _Watch extends Mock implements WatchCallGifts {}

const _rose = Gift(
  id: 'rose',
  name: 'Rose',
  emoji: '🌹',
  tier: GiftTier.common,
  diamondPrice: 1500,
);
const _ring = Gift(
  id: 'diamond_ring',
  name: 'Diamond Ring',
  emoji: '💎',
  tier: GiftTier.epic,
  diamondPrice: 25000,
);

GiftEvent _event(String id) => GiftEvent(
  giftTransactionId: id,
  giftId: 'rose',
  giftName: 'Rose',
  emoji: '🌹',
  tier: GiftTier.common,
  diamondValue: 1500,
  senderId: 'u1',
  senderName: 'Asha',
  recipientId: 'h1',
  recipientName: 'Ananya',
  callId: 'c1',
  sentAt: DateTime.now().toUtc(),
);

CallState _live({
  CallRole role = CallRole.caller,
  CallUiStatus status = CallUiStatus.active,
}) => CallState(
  status: status,
  mediaJoined: true,
  session: session(
    role: role,
    startedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue(
      SendGiftInput(
        callId: 'c',
        giftId: 'g',
        recipientUserId: 'r',
        idempotencyKey: IdempotencyKey.generate(),
      ),
    );
  });

  late StreamController<GiftEvent> live;
  late _Send send;

  Future<(GiftSheetBloc, GiftCelebrationCubit)> pump(
    WidgetTester t,
    CallState s, {
    Stream<CallState>? states,
    Size size = phone,
    double textScale = 1,
    bool reducedMotion = false,
    int balance = 10000,
  }) async {
    DashuriText.useGoogleFonts = false;
    setWindow(t, size);
    final call = _Call();
    if (states != null) {
      whenListen(call, states, initialState: s);
    } else {
      when(() => call.state).thenReturn(s);
    }
    final catalogue = _Catalogue();
    when(
      () => catalogue(any()),
    ).thenAnswer((_) async => const Success([_rose, _ring]));
    final bal = _Balance();
    when(() => bal(any())).thenAnswer((_) async => Success(balance));
    final history = _History();
    when(() => history(any())).thenAnswer((_) async => const Success([]));
    final watch = _Watch();
    when(() => watch(any())).thenAnswer((_) => live.stream);
    final sheet = GiftSheetBloc(catalogue: catalogue, balance: bal, send: send);
    final celebrations = GiftCelebrationCubit(history: history, watch: watch);
    addTearDown(sheet.close);
    addTearDown(celebrations.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<CallBloc>.value(value: call),
              BlocProvider.value(value: sheet),
              BlocProvider.value(value: celebrations),
            ],
            child: const CallPage(
              views: FakeViews(),
              manageSystemUi: false,
              giftsEnabled: true,
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.hostDashboard,
          builder: (_, st) => Scaffold(body: Text('home:${st.uri.query}')),
        ),
        GoRoute(
          path: RoutePaths.wallet,
          builder: (_, _) => const Scaffold(body: Text('wallet-page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      MaterialApp.router(
        theme: DashuriTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
      ),
    );
    await t.pump();
    await t.pump();
    return (sheet, celebrations);
  }

  setUp(() {
    live = StreamController<GiftEvent>.broadcast();
    send = _Send();
  });
  tearDown(() => live.close());

  testWidgets('customer: Gift control where camera on/off was; host: none', (
    t,
  ) async {
    await pump(t, _live());
    expect(find.byTooltip('Send a gift'), findsOneWidget);
    expect(find.byTooltip('Turn camera off'), findsNothing);
    await pump(t, _live(role: CallRole.receiver));
    expect(find.byTooltip('Send a gift'), findsNothing);
    expect(find.byTooltip('Turn camera off'), findsNothing);
  });

  testWidgets('Gift control is disabled when the call is not active', (
    t,
  ) async {
    await pump(t, _live(status: CallUiStatus.paused));
    final control = t.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('Send a gift'),
        matching: find.byType(InkWell),
      ),
    );
    expect(control.onTap, isNull);
  });

  group('responsive (P0)', () {
    for (final MapEntry(key: name, value: size) in auditSizes.entries) {
      for (final scale in auditTextScales) {
        testWidgets('$name @${scale}x: Gift control fits with every control', (
          t,
        ) async {
          await pump(t, _live(), size: size, textScale: scale);
          expectTextInsideWindow(t);
          for (final c in [
            'Mute microphone',
            'Send a gift',
            'Report',
            'End call',
          ]) {
            expectReachable(t, find.byTooltip(c), reason: c);
            expect(
              t.getRect(find.byTooltip(c)).shortestSide,
              greaterThanOrEqualTo(48),
              reason: c,
            );
          }
        });
      }
    }
  });

  testWidgets(
    'sheet: catalogue, selection, cost, balance; insufficient blocks Send',
    (t) async {
      await pump(t, _live(), balance: 2000);
      await t.tap(find.byTooltip('Send a gift'));
      await t.pumpAndSettle();
      expect(find.text('Send a gift to Ananya'), findsOneWidget);
      expect(find.text('Rose'), findsOneWidget);
      expect(find.text('Diamond Ring'), findsOneWidget);
      await t.tap(find.text('Diamond Ring'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Not enough Diamonds for Diamond Ring'),
        findsOneWidget,
      );
      expect(find.text('Open wallet'), findsOneWidget);
      final sendButton = t.widget<FilledButton>(find.byType(FilledButton));
      expect(sendButton.onPressed, isNull);
      verifyNever(() => send(any()));
      await t.tap(find.text('Open wallet'));
      await t.pumpAndSettle();
      expect(find.text('wallet-page'), findsOneWidget);
    },
  );

  testWidgets('send: only the server receipt celebrates; sheet closes', (
    t,
  ) async {
    final gate = Completer<Result<GiftReceipt>>();
    when(() => send(any())).thenAnswer((_) => gate.future);
    final (_, celebrations) = await pump(t, _live());
    await t.tap(find.byTooltip('Send a gift'));
    await t.pumpAndSettle();
    await t.tap(find.text('Rose'));
    await t.pumpAndSettle();
    await t.tap(find.text('Send Rose'));
    await t.pump();
    // Tapped, not confirmed: no celebration yet.
    expect(celebrations.state.current, isNull);
    gate.complete(
      Success(
        GiftReceipt(
          event: _event('g1'),
          availableDiamonds: 8500,
          replayed: false,
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(celebrations.state.current?.giftTransactionId, 'g1');
    expect(find.text('Send a gift to Ananya'), findsNothing);
    expect(find.text('You sent Rose to Ananya'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    expect(celebrations.state.current, isNull);
  });

  testWidgets('celebration never blocks controls and stays out of their way', (
    t,
  ) async {
    final (_, celebrations) = await pump(t, _live(role: CallRole.receiver));
    live.add(_event('g1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('gift-particles')), findsOneWidget);
    expect(find.text('Asha sent you Rose'), findsOneWidget);
    final overlay = find.byType(GiftCelebrationOverlay);
    expect(
      find.ancestor(
        of: find.text('Asha sent you Rose'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    // Controls stay tappable during the celebration.
    final end = find.byTooltip('End call');
    expect(end.hitTestable(), findsOneWidget);
    expect(find.byTooltip('Report').hitTestable(), findsOneWidget);
    // The banner sits above the controls, never over them.
    final banner = t.getRect(find.text('Asha sent you Rose'));
    expect(banner.bottom, lessThan(t.getRect(end).top));
    expect(overlay, findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    expect(celebrations.state.current, isNull);
  });

  testWidgets('reduced motion: static banner, no particles', (t) async {
    await pump(t, _live(role: CallRole.receiver), reducedMotion: true);
    live.add(_event('g1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Asha sent you Rose'), findsOneWidget);
    expect(find.byKey(const Key('gift-particles')), findsNothing);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('duplicate realtime deliveries celebrate once', (t) async {
    final (_, celebrations) = await pump(t, _live(role: CallRole.receiver));
    live
      ..add(_event('g1'))
      ..add(_event('g1'));
    await t.pump();
    expect(celebrations.state.pending, 0);
    await t.pump(const Duration(seconds: 6));
    expect(celebrations.state.current, isNull);
    expect(celebrations.state.sequence, 1);
  });

  testWidgets('host: a declined call returns to Host Home', (t) async {
    final declined = CallState(
      status: CallUiStatus.ended,
      requestedEndReason: 'declined',
      session: session(role: CallRole.receiver, phase: CallPhase.declined),
    );
    await pump(
      t,
      _live(role: CallRole.receiver, status: CallUiStatus.incoming),
      states: Stream.value(declined),
    );
    await t.pumpAndSettle();
    expect(find.text('home:after=declined'), findsOneWidget);
  });
}
