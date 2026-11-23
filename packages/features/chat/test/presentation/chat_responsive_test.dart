// EXPERIMENT — P0 responsiveness audit for normal chat (CH02), the in-call
// chat panel and the inbox (CH01): every required viewport, text scales up
// to 2x, long names / messages / unbroken strings, and the keyboard open.
// Real cubits on the fake server (helpers/fake_chat_server.dart).

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_chat_server.dart';
import '../helpers/layout_audit.dart';

const me = 'me';
// Long display name (the fake server uses the user id as the name).
const peer = 'Ananya-Lakshmi Venkataraman-Subramaniam Iyer-Krishnamurthy';
final unbroken = 'a' * 300; // no break opportunities at all
final longText = List.filled(
  60,
  'This is a long message that wraps.',
).join(' ');
const longLast = 'LATEST: the newest message should stay visible at the bottom';

Future<FakeChatServer> seeded() async {
  final server = FakeChatServer();
  final c = cubitFor(server, me, peerUserId: peer);
  await c.start();
  final p = cubitFor(server, peer, peerUserId: me);
  await p.start();
  await c.send(longText.substring(0, 1000));
  await p.send(unbroken);
  await c.send('🙂 short');
  await p.send('email-like-but-allowed-text-${'x' * 120}');
  await p.send(longLast);
  await c.close();
  await p.close();
  return server;
}

Future<void> pumpIn(
  WidgetTester t,
  Widget child, {
  required Size size,
  required double scale,
  ThemeData? theme,
}) async {
  DashuriText.useGoogleFonts = false;
  setWindow(t, size);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => child)],
    errorBuilder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(
      theme: theme ?? DashuriTheme.light(),
      routerConfig: router,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: name, value: size) in auditSizes.entries) {
    for (final scale in auditTextScales) {
      final label = '$name @${scale}x';

      testWidgets('$label: normal chat with long content and keyboard', (
        t,
      ) async {
        final server = (await t.runAsync(seeded))!;
        addTearDown(server.dispose);
        final cubit = cubitFor(
          server,
          me,
          peerUserId: peer,
          conversationId: server.conversationOf(me, peer),
        );
        addTearDown(cubit.close);
        await t.runAsync(cubit.start);
        await pumpIn(
          t,
          BlocProvider.value(value: cubit, child: const ConversationPage()),
          size: size,
          scale: scale,
        );
        expectTextInsideWindow(t);
        expectReachable(t, find.byTooltip('Send'));
        // The newest message's last line is in view (a message taller than
        // the screen scrolls, by design).
        final newest = t.getRect(find.text(longLast));
        final composerTop = t.getRect(find.byType(TextField)).top;
        expect(
          newest.bottom > 0 && newest.bottom <= composerTop,
          isTrue,
          reason: 'newest message at $newest, composer at $composerTop',
        );

        // Keyboard open: composer and newest message stay visible.
        setKeyboard(t, size.height * .4);
        await t.pumpAndSettle();
        expectTextInsideWindow(t);
        expectReachable(t, find.byTooltip('Send'));
        expectReachable(t, find.byType(TextField));

        // Typing a long multi-line draft grows the composer, not the page.
        await t.enterText(find.byType(TextField), longText.substring(0, 900));
        await t.pumpAndSettle();
        expectReachable(t, find.byTooltip('Send'));
        await t.tap(find.byTooltip('Send'));
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pumpAndSettle();
        expectTextInsideWindow(t);
        expectReachable(t, find.byTooltip('Send'));
      });

      testWidgets('$label: in-call panel at the heights the call screen '
          'gives it', (t) async {
        final server = (await t.runAsync(seeded))!;
        addTearDown(server.dispose);
        final cubit = cubitFor(server, me, peerUserId: peer, callId: 'call');
        addTearDown(cubit.close);
        await t.runAsync(cubit.start);
        for (final h in [120.0, 150.0, 240.0, 420.0]) {
          final height = h.clamp(0.0, size.height - 40);
          await pumpIn(
            t,
            Scaffold(
              backgroundColor: Colors.black,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: height,
                  child: BlocProvider.value(
                    value: cubit,
                    child: InCallChatPanel(onClose: () {}, peerName: peer),
                  ),
                ),
              ),
            ),
            size: size,
            scale: scale,
            theme: DashuriTheme.dark(),
          );
          expectTextInsideWindow(t);
          expectReachable(t, find.byTooltip('Send'), reason: 'send @$height');
          if (height >=
              InCallChatPanel.minFullHeight(TextScaler.linear(scale))) {
            expectReachable(t, find.byTooltip('Close chat'));
          }
        }
      });

      testWidgets('$label: inbox with long names and previews', (t) async {
        final server = (await t.runAsync(seeded))!;
        addTearDown(server.dispose);
        final repo = server.repoFor(me);
        final inbox = ConversationsCubit(
          ListConversations(repo),
          WatchChatHints(repo),
          GetCurrentUserId(repo),
        );
        addTearDown(inbox.close);
        await t.runAsync(inbox.load);
        await pumpIn(
          t,
          BlocProvider.value(
            value: inbox,
            child: ConversationsPage(
              conversationBuilder: (_, c) => Text('open ${c.id}'),
            ),
          ),
          size: size,
          scale: scale,
        );
        expectTextInsideWindow(t);
        expect(find.textContaining('Ananya'), findsWidgets);
      });
    }
  }

  testWidgets('in-call panel states (loading, failed) fit a small panel', (
    t,
  ) async {
    final server = FakeChatServer();
    addTearDown(server.dispose);
    // A stranger opening a conversation they are not in → failed state.
    final cubit = cubitFor(
      server,
      'stranger',
      peerUserId: peer,
      conversationId: 'nope',
      callId: 'call',
    );
    addTearDown(cubit.close);
    await t.runAsync(cubit.start);
    await pumpIn(
      t,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 160,
            child: BlocProvider.value(
              value: cubit,
              child: InCallChatPanel(onClose: () {}, peerName: peer),
            ),
          ),
        ),
      ),
      size: const Size(320, 568),
      scale: 2,
      theme: DashuriTheme.dark(),
    );
    expect(cubit.state.status, ConversationStatus.failed);
    expectTextInsideWindow(t);
    // Long explanations scroll inside the panel; the action is reachable.
    await t.ensureVisible(find.text('Try again'));
    await t.pumpAndSettle();
    expectReachable(t, find.text('Try again'));
  });

  testWidgets('normal chat labels messages sent during a call and shows '
      'Sent/Read', (t) async {
    final server = FakeChatServer();
    addTearDown(server.dispose);
    final inCall = cubitFor(server, me, peerUserId: peer, callId: 'call');
    await t.runAsync(() async {
      await inCall.start();
      await inCall.send('sent in the call');
      await inCall.close();
    });
    server.endCall('call'); // the session joins normal Chat
    final cubit = cubitFor(
      server,
      me,
      peerUserId: peer,
      conversationId: server.conversationOf(me, peer),
    );
    addTearDown(cubit.close);
    await t.runAsync(cubit.start);
    await pumpIn(
      t,
      BlocProvider.value(value: cubit, child: const ConversationPage()),
      size: const Size(390, 844),
      scale: 1,
    );
    expect(find.textContaining('During video call'), findsOneWidget);
    expect(find.textContaining('Sent'), findsOneWidget);

    // The peer reads it: the receipt flips to Read.
    final p = cubitFor(server, peer, peerUserId: me);
    addTearDown(p.close);
    await t.runAsync(() async {
      await p.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await t.pumpAndSettle();
    expect(find.textContaining('Read'), findsOneWidget);
  });
}
