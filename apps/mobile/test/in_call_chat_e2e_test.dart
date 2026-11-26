// EXPERIMENT — unified chat + in-call messaging, end to end in the UI:
// the real call screen (CallPage) with the real in-call panel
// (FeatureChatInCallChat → feature_chat), and the real inbox conversation
// page, both on one fake chat server with the Go API's rules.
//
// The server double lives with the chat tests and is imported by path.

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_mobile/app/di/in_call_chat_adapter.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../../../packages/features/chat/test/helpers/fake_chat_server.dart';

const customer = 'cust';
const host = 'host';

/// Records every event; the call screen must send none for chat actions.
final class RecordingCallBloc extends Bloc<CallBlocEvent, CallState>
    implements CallBloc {
  RecordingCallBloc(super.initial) {
    on<CallBlocEvent>((e, _) => events.add(e));
  }

  final events = <CallBlocEvent>[];
}

final class _Views implements VideoViewFactory {
  const _Views();
  @override
  Widget localPreview({Widget? placeholder}) =>
      const ColoredBox(color: Colors.blue);
  @override
  Widget remoteVideo({Widget? placeholder}) =>
      const ColoredBox(color: Colors.green, child: Text('remote-video'));
}

CallState liveCall() => CallState(
  status: CallUiStatus.active,
  mediaJoined: true,
  session: CallSession(
    callId: 'call-1',
    role: CallRole.caller,
    peerUserId: host,
    phase: CallPhase.active,
    ratePerMinute: 2400,
    billedSeconds: 60,
    diamondsCharged: 2400,
    isFreeCall: false,
    endReason: null,
    peer: const CallPeer(userId: host, displayName: 'Ananya'),
    startedAt: DateTime.now().toUtc(),
  ),
);

GetIt chatLocator(FakeChatServer server, String user) {
  final repo = server.repoFor(user);
  return GetIt.asNewInstance()
    ..registerFactory(() => ListMessages(repo))
    ..registerFactory(() => SendMessage(repo))
    ..registerFactory(() => StartConversation(repo))
    ..registerFactory(() => MarkConversationRead(repo))
    ..registerFactory(() => ListConversations(repo))
    ..registerFactory(() => WatchChatHints(repo))
    ..registerFactory(() => WatchReadHints(repo))
    ..registerFactory(() => WatchChatHintMessages(repo))
    ..registerFactory(() => GetCurrentUserId(repo));
}

Future<void> real(WidgetTester t, [int ms = 20]) async {
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await t.pump();
}

void main() {
  late FakeChatServer server;
  setUp(() {
    DashuriText.useGoogleFonts = false;
    server = FakeChatServer();
  });
  tearDown(() => server.dispose());

  Future<RecordingCallBloc> pumpCall(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final bloc = RecordingCallBloc(liveCall());
    addTearDown(bloc.close);
    await t.pumpWidget(
      MaterialApp(
        theme: DashuriTheme.light(),
        home: BlocProvider<CallBloc>.value(
          value: bloc,
          child: CallPage(
            views: const _Views(),
            manageSystemUi: false,
            chat: FeatureChatInCallChat(chatLocator(server, customer)),
          ),
        ),
      ),
    );
    await t.pump(); // post-frame: the live call opens its chat
    await real(t);
    return bloc;
  }

  testWidgets('send in the call → the peer\'s normal Chat gets it when the '
      'call ends; the call got no events', (t) async {
    final bloc = await pumpCall(t);
    await t.tap(find.byTooltip('Open chat'));
    await real(t);
    await t.pumpAndSettle();
    // The panel is open: it has no title bar (it floats over the video),
    // just the composer with its own close control.
    expect(find.widgetWithText(TextField, 'Message…'), findsOneWidget);
    expect(find.byTooltip('Close chat'), findsWidgets);

    await t.enterText(find.byType(TextField), 'Your audio is breaking up');
    await t.tap(find.byTooltip('Send'));
    await real(t);
    await t.pumpAndSettle();
    expect(find.text('Your audio is breaking up'), findsOneWidget);
    expect(find.text('remote-video'), findsOneWidget); // video still there

    final conv = server.conversationOf(customer, host);
    final stored = server.stored(conv).single;
    expect(stored.context, MessageContext.call);
    expect(stored.senderId, customer);
    expect(bloc.events, isEmpty);

    // The host opens normal Chat during the call: same conversation, but
    // the live call's session is not in it yet.
    final inbox = cubitFor(
      server,
      host,
      peerUserId: customer,
      conversationId: conv,
    );
    addTearDown(inbox.close);
    await t.runAsync(inbox.start);
    await t.pumpWidget(
      MaterialApp(
        theme: DashuriTheme.light(),
        home: BlocProvider.value(value: inbox, child: const ConversationPage()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Your audio is breaking up'), findsNothing);

    // The call ends server-side: the open Chat refreshes and shows it.
    server.endCall('call-1');
    await real(t);
    await t.pumpAndSettle();
    expect(find.text('Your audio is breaking up'), findsOneWidget);
    expect(find.textContaining('During video call'), findsOneWidget);
  });

  testWidgets('a reply from the peer\'s in-call panel reaches the closed '
      'panel (badge, preview, message); inbox messages stay out', (t) async {
    final bloc = await pumpCall(t);
    final conv = server.conversationOf(customer, host);
    final hostInbox = cubitFor(
      server,
      host,
      peerUserId: customer,
      conversationId: conv,
    );
    final hostPanel = cubitFor(
      server,
      host,
      peerUserId: customer,
      conversationId: conv,
      callId: 'call-1',
    );
    addTearDown(hostInbox.close);
    addTearDown(hostPanel.close);
    await t.runAsync(() async {
      await hostInbox.start();
      await hostInbox.send('Old-style inbox message');
      await hostPanel.start();
      await hostPanel.send('Replying in the call');
    });
    await real(t);
    expect(find.bySemanticsLabel('Open chat, 1 unread'), findsOneWidget);
    expect(find.textContaining('Replying in the call'), findsOneWidget);

    await t.tap(find.byTooltip('Open chat'));
    await real(t);
    await t.pumpAndSettle();
    expect(find.text('Replying in the call'), findsOneWidget);
    expect(find.text('Old-style inbox message'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('unread')), findsNothing);
    // Opening marked it read: the host's side shows Read.
    await real(t);
    expect(
      hostPanel.state.deliveryOf(hostPanel.state.bubbles.single),
      DeliveryState.read,
    );
    expect(bloc.events, isEmpty);
  });
}
