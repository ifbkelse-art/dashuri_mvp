// EXPERIMENT — in-call chat on the call screen: continuity (opening and
// closing the chat never sends a call event, so it cannot end, pause or
// bill), unread badge, preview, Back behaviour and the P0 responsiveness
// matrix. The chat itself is a test double here; the real chat panel is
// exercised end-to-end in apps/mobile/test/in_call_chat_e2e_test.dart.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_video_call/src/presentation/widgets/call_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';
import '../layout_audit.dart';

class _Call extends MockBloc<CallBlocEvent, CallState> implements CallBloc {}

final _long = 'Ananya-Lakshmi-Venkataraman-Subramaniam-Iyer-Krishnamurthy' * 2;

class FakeChat implements InCallChat {
  final sessions = <FakeChatSession>[];
  final opened = <String>[];

  @override
  InCallChatSession open({
    required String callId,
    required String peerUserId,
    required String peerName,
  }) {
    opened.add('$callId/$peerUserId/$peerName');
    final s = FakeChatSession();
    sessions.add(s);
    return s;
  }
}

class FakeChatSession implements InCallChatSession {
  @override
  final ValueNotifier<int> unseen = ValueNotifier(0);
  @override
  final ValueNotifier<String?> preview = ValueNotifier(null);
  final visible = <bool>[];
  var closed = false;

  @override
  Widget buildPanel(BuildContext context, {required VoidCallback onClose}) =>
      Material(
        key: const Key('chat-panel'),
        color: Colors.black87,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chat with $_long',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Close chat',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                reverse: true,
                children: [Text('x' * 600), Text('$_long ' * 4)],
              ),
            ),
            const TextField(key: Key('composer')),
          ],
        ),
      );

  @override
  void setVisible(bool v) => visible.add(v);

  @override
  void dismissPreview() => preview.value = null;

  @override
  Future<void> close() async => closed = true;
}

CallState live({bool low = false}) => CallState(
  status: CallUiStatus.active,
  mediaJoined: true,
  lowBalanceSecondsRemaining: low ? 25 : null,
  session: session(
    startedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 3)),
    moderationEnds: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    charged: 123456789,
  ),
);

void main() {
  setUpAll(() => registerFallbackValue(const CallEndRequested()));

  Future<(_Call, FakeChat)> pump(
    WidgetTester t,
    CallState s, {
    Size size = phone,
    double textScale = 1,
    double keyboard = 0,
    Stream<CallState>? states,
  }) async {
    DashuriText.useGoogleFonts = false;
    setWindow(t, size, keyboard: keyboard);
    final b = _Call();
    if (states != null) {
      whenListen(b, states, initialState: s);
    } else {
      when(() => b.state).thenReturn(s);
    }
    final chat = FakeChat();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<CallBloc>.value(
            value: b,
            child: CallPage(
              views: const FakeViews(),
              manageSystemUi: false,
              chat: chat,
            ),
          ),
        ),
      ],
      errorBuilder: (_, st) => Scaffold(body: Text('route:${st.uri}')),
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      MaterialApp.router(
        theme: DashuriTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await t.pump();
    await t.pump();
    return (b, chat);
  }

  // Regression: on a tablet (or phone) in landscape, opening the keyboard
  // leaves too little height for the top bar, so it leaves the layout.
  // The chat must survive that relayout: the field keeps focus and text,
  // and the keyboard is not closed again.
  for (final (name, size, keyboard) in [
    ('tablet landscape', const Size(1180, 820), 420.0),
    ('small tablet landscape', const Size(1024, 768), 400.0),
    ('phone landscape', const Size(844, 390), 200.0),
  ]) {
    testWidgets('$name: opening the keyboard keeps the chat field focused', (
      t,
    ) async {
      await pump(t, live(), size: size);
      await t.tap(find.byTooltip('Open chat'));
      await t.pumpAndSettle();
      final composer = find.byKey(const Key('composer'));
      await t.tap(composer);
      await t.pump();
      await t.enterText(composer, 'typing during the call');
      final before = t.state<EditableTextState>(find.byType(EditableText));

      setKeyboard(t, keyboard);
      await t.pumpAndSettle();

      final after = t.state<EditableTextState>(find.byType(EditableText));
      expect(identical(before, after), isTrue, reason: 'field was rebuilt');
      expect(after.widget.focusNode.hasFocus, isTrue);
      expect(find.text('typing during the call'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('no chat control before the call is live', (t) async {
    final (_, chat) = await pump(
      t,
      CallState(
        status: CallUiStatus.ringing,
        session: session(phase: CallPhase.ringing),
      ),
    );
    expect(find.byTooltip('Open chat'), findsNothing);
    expect(chat.opened, isEmpty);
  });

  testWidgets('selfie camera only: no flip-camera control and, since the '
      'gifts spec (2026-11-26), no camera on/off control', (t) async {
    await pump(t, live());
    expect(find.byTooltip('Flip camera'), findsNothing);
    expect(find.byIcon(Icons.cameraswitch_rounded), findsNothing);
    expect(find.byTooltip('Turn camera off'), findsNothing);
    expect(find.byTooltip('Turn camera on'), findsNothing);
    expect(find.byIcon(Icons.videocam_off_rounded), findsNothing);
    // The camera stays on: the local preview is shown, not the off tile.
    expect(find.text('local-video'), findsOneWidget);
  });

  testWidgets('10: opening and closing the chat keeps the call: video, '
      'controls, no call events, one session', (t) async {
    final (b, chat) = await pump(t, live());
    expect(chat.opened, ['c1/h1/Ananya']);
    final s = chat.sessions.single;

    await t.tap(find.byTooltip('Open chat'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chat-panel')), findsOneWidget);
    expect(find.text('remote-video'), findsOneWidget);
    expect(find.byTooltip('End call'), findsOneWidget);
    expect(find.byTooltip('Mute microphone'), findsOneWidget);

    await t.tap(
      find.descendant(
        of: find.byKey(const Key('chat-panel')),
        matching: find.byTooltip('Close chat'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chat-panel')), findsNothing);

    // Reopen from the control, close from the control.
    await t.tap(find.byTooltip('Open chat'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Close chat').last);
    await t.pumpAndSettle();

    expect(s.visible, [true, false, true, false]);
    expect(chat.opened, hasLength(1));
    // 11 (client side): no call event of any kind, so no end, no billing.
    verifyNever(() => b.add(any()));
  });

  testWidgets('Back closes the chat first and never ends the call', (t) async {
    final (b, chat) = await pump(t, live());
    await t.tap(find.byTooltip('Open chat'));
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chat-panel')), findsNothing);
    expect(find.text('End this call?'), findsNothing);
    verifyNever(() => b.add(any()));
    // A second Back asks before ending (existing behaviour).
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('End this call?'), findsOneWidget);
    expect(chat.sessions.single.visible, [true, false]);
  });

  testWidgets('unread badge and message preview; tapping opens', (t) async {
    final (_, chat) = await pump(t, live());
    final s = chat.sessions.single;
    s.unseen.value = 3;
    s.preview.value = 'Are you there? $_long';
    await t.pump();
    expect(find.bySemanticsLabel('Open chat, 3 unread'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expectTextInsideWindow(t);
    await t.tap(find.textContaining('Are you there?'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chat-panel')), findsOneWidget);
    expect(s.visible, [true]);
  });

  testWidgets('the preview hides itself after a few seconds', (t) async {
    final (_, chat) = await pump(t, live());
    chat.sessions.single.preview.value = 'hello';
    await t.pump();
    expect(find.textContaining('hello'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    expect(find.textContaining('hello'), findsNothing);
  });

  testWidgets('the call ending closes the panel and the session', (t) async {
    final ctrl = StreamController<CallState>();
    addTearDown(ctrl.close);
    final (_, chat) = await pump(t, live(), states: ctrl.stream);
    await t.tap(find.byTooltip('Open chat'));
    await t.pumpAndSettle();
    ctrl.add(live().copyWith(status: CallUiStatus.ending));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300)); // spinner never settles
    expect(find.byKey(const Key('chat-panel')), findsNothing);
    await t.pumpWidget(const SizedBox());
    expect(chat.sessions.single.closed, isTrue);
  });

  group('responsive (P0)', () {
    for (final MapEntry(key: name, value: size) in auditSizes.entries) {
      for (final scale in auditTextScales) {
        final label = '$name @${scale}x';

        testWidgets('$label: chat closed — controls fit, 48px targets', (
          t,
        ) async {
          await pump(t, live(low: true), size: size, textScale: scale);
          expectTextInsideWindow(t);
          for (final c in [
            'Mute microphone',
            'Open chat',
            'Report',
            'End call',
          ]) {
            expectReachable(t, find.byTooltip(c), reason: c);
            final r = t.getRect(find.byTooltip(c));
            expect(r.shortestSide, greaterThanOrEqualTo(48), reason: c);
          }
        });

        testWidgets('$label: chat open — panel between top bar and controls', (
          t,
        ) async {
          await pump(t, live(low: true), size: size, textScale: scale);
          await t.tap(find.byTooltip('Open chat'));
          await t.pumpAndSettle();
          expectTextInsideWindow(t);
          final panel = t.getRect(find.byKey(const Key('chat-panel')));
          final end = t.getRect(find.byTooltip('End call'));
          expectReachable(t, find.byKey(const Key('chat-panel')));
          expectReachable(t, find.byTooltip('End call'));
          expect(panel.bottom <= end.top, isTrue, reason: '$panel vs $end');
          expectReachable(t, find.byKey(const Key('composer')));
        });

        testWidgets('$label: typing — composer above the keyboard', (t) async {
          final keyboard = size.height * .4;
          await pump(t, live(), size: size, textScale: scale);
          await t.tap(find.byTooltip('Open chat'));
          await t.pumpAndSettle();
          setKeyboard(t, keyboard);
          await t.pumpAndSettle();
          expectTextInsideWindow(t);
          expectReachable(t, find.byKey(const Key('composer')));
          expectReachable(t, find.byKey(const Key('chat-panel')));
          // Closing the keyboard brings the controls back.
          setKeyboard(t, 0);
          await t.pumpAndSettle();
          expectReachable(t, find.byTooltip('End call'));
        });
      }
    }
  });

  test('controls bar: one row when it fits, never under 48px', () {
    expect(CallControlsBar.layoutFor(6, 440), (56.0, 12.0, true));
    final (size360, _, row360) = CallControlsBar.layoutFor(6, 336);
    expect(size360, greaterThanOrEqualTo(48));
    expect(row360, isTrue);
    final (size320, _, row320) = CallControlsBar.layoutFor(6, 296);
    expect(size320, 48);
    expect(row320, isFalse); // wraps to a second row instead of shrinking
  });
}
