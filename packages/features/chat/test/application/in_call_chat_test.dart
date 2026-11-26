import 'dart:async';

// EXPERIMENT — video-call session chat, client side. Each call has its own
// session in the pair's one conversation; normal Chat gets it when the call
// ends. Two users,
// real cubits, one fake server with the Go API's rules (see
// helpers/fake_chat_server.dart). Server rules are separately verified on
// Postgres in backend/internal/modules/chat/chat_integration_test.go.

import 'package:feature_chat/feature_chat.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_chat_server.dart';

const customer = 'cust';
const host = 'host';
const callId = 'call-1';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

List<String> bodies(ConversationCubit c) =>
    c.state.bubbles.map((b) => b.body).toList();

void main() {
  late FakeChatServer server;

  setUp(() => server = FakeChatServer());
  tearDown(() => server.dispose());

  /// The customer's in-call panel and the host's in-call panel, both live.
  Future<(ConversationCubit, ConversationCubit)> bothInCall({
    bool customerVisible = true,
    bool hostVisible = true,
  }) async {
    final c = cubitFor(
      server,
      customer,
      peerUserId: host,
      callId: callId,
      visible: customerVisible,
    );
    final h = cubitFor(
      server,
      host,
      peerUserId: customer,
      callId: callId,
      visible: hostVisible,
    );
    await c.start();
    await h.start();
    addTearDown(c.close);
    addTearDown(h.close);
    return (c, h);
  }

  test('1+2: a message sent during the call reaches the peer immediately; '
      'normal Chat gets it when the call ends', () async {
    final (c, h) = await bothInCall();
    await c.send('Can you hear me?');
    await settle();

    expect(bodies(h), ['Can you hear me?']);
    expect(h.state.bubbles.single.context, MessageContext.call);
    expect(c.state.bubbles.single.context, MessageContext.call);

    // The host's normal Chat: same conversation, session not in it yet.
    final conv = server.conversationOf(customer, host);
    final inbox = cubitFor(
      server,
      host,
      peerUserId: customer,
      conversationId: conv,
    );
    addTearDown(inbox.close);
    await inbox.start();
    expect(inbox.state.conversationId, conv);
    expect(bodies(inbox), isEmpty);

    // The call ends server-side: the open Chat refreshes from the hint.
    server.endCall(callId);
    await settle();
    expect(bodies(inbox), ['Can you hear me?']);
  });

  test('gift lines: shown once to both sides in the call, kept in normal '
      'Chat after the call, in order with messages', () async {
    final (c, h) = await bothInCall();
    await c.send('Hello!');
    await settle();
    server.serverGift(
      customer: customer,
      host: host,
      callId: callId,
      body: '🌹 Asha sent Rose to Meera.',
      deliveries: 3, // duplicate realtime delivery
    );
    await settle();
    for (final side in [c, h]) {
      expect(bodies(side), ['Hello!', '🌹 Asha sent Rose to Meera.']);
      expect(side.state.bubbles.last.isGift, isTrue);
    }
    // Same in the hint-less fallback (a re-fetch must not duplicate it).
    final conv = server.conversationOf(customer, host);
    final inbox = cubitFor(
      server,
      host,
      peerUserId: customer,
      conversationId: conv,
    );
    addTearDown(inbox.close);
    await inbox.start();
    expect(
      bodies(inbox),
      isEmpty,
      reason: 'session stays out of Chat while live',
    );
    server.endCall(callId);
    await settle();
    expect(bodies(inbox), ['Hello!', '🌹 Asha sent Rose to Meera.']);
    expect(inbox.state.bubbles.where((b) => b.isGift), hasLength(1));
  });

  test('3+4: the session is isolated: normal-chat messages, even ones sent '
      'during the call, stay out of the in-call panel', () async {
    final (c, _) = await bothInCall();
    final conv = server.conversationOf(customer, host);
    final hostInbox = cubitFor(
      server,
      host,
      peerUserId: customer,
      conversationId: conv,
    );
    addTearDown(hostInbox.close);
    await hostInbox.start();

    await hostInbox.send('Sent from the inbox');
    await settle();
    expect(bodies(c), isEmpty);
    expect(bodies(hostInbox), ['Sent from the inbox']);
  });

  test('a new call does not load earlier chat history; one conversation '
      'per pair', () async {
    final before = cubitFor(server, customer, peerUserId: host);
    await before.start();
    await before.send('Hi before the call');
    await before.close();

    final (c, h) = await bothInCall();
    expect(bodies(c), isEmpty);
    expect(bodies(h), isEmpty);
    expect(c.state.conversationId, h.state.conversationId);
    expect(c.state.conversationId, server.conversationOf(customer, host));
  });

  test('5: after the call the session is appended to normal Chat; earlier '
      'history intact; chatting continues', () async {
    final before = cubitFor(server, customer, peerUserId: host);
    await before.start();
    await before.send('before the call');
    await before.close();

    final (c, h) = await bothInCall();
    await c.send('during the call');
    await h.send('reply during the call');
    await settle();
    // The call ends: the call screen closes its chat; the server ends it.
    await c.close();
    await h.close();
    server.endCall(callId);
    server.endCall(callId); // repeated call-end event: no effect

    final conv = server.conversationOf(customer, host);
    for (final user in [customer, host]) {
      final inbox = cubitFor(
        server,
        user,
        peerUserId: user == host ? customer : host,
        conversationId: conv,
      );
      addTearDown(inbox.close);
      await inbox.start();
      expect(bodies(inbox), [
        'before the call',
        'during the call',
        'reply during the call',
      ]);
    }
    final after = cubitFor(
      server,
      customer,
      peerUserId: host,
      conversationId: conv,
    );
    addTearDown(after.close);
    await after.start();
    await after.send('thanks for the call');
    expect(server.stored(conv).map((m) => m.body), [
      'before the call',
      'during the call',
      'reply during the call',
      'thanks for the call',
    ]);
  });

  test('multiple calls: each session is independent and all join the same '
      'conversation in order', () async {
    Future<ConversationCubit> panel(String user, String call) async {
      final p = cubitFor(
        server,
        user,
        peerUserId: user == host ? customer : host,
        callId: call,
      );
      addTearDown(p.close);
      await p.start();
      return p;
    }

    final c1 = await panel(customer, 'call-1');
    await c1.send('first call');
    server.endCall('call-1');

    final c2 = await panel(customer, 'call-2');
    final h2 = await panel(host, 'call-2');
    expect(bodies(c2), isEmpty);
    await h2.send('second call');
    await settle();
    expect(bodies(c2), ['second call']);
    server.endCall('call-2');

    final conv = server.conversationOf(customer, host);
    final inbox = cubitFor(
      server,
      host,
      peerUserId: customer,
      conversationId: conv,
    );
    addTearDown(inbox.close);
    await inbox.start();
    expect(bodies(inbox), ['first call', 'second call']);
  });

  test('6: a lost response is retried with the same key: one message, one '
      'bubble', () async {
    final (c, h) = await bothInCall();
    server.loseNextSendResponse = true;
    await c.send('hello?');
    final failed = c.state.bubbles.single;
    expect(c.state.deliveryOf(failed), DeliveryState.failed);

    await c.retrySend(failed.localId); // reconnect + retry
    await settle();
    final conv = server.conversationOf(customer, host);
    expect(server.stored(conv), hasLength(1));
    expect(server.sendRequests, 2);
    expect(bodies(c), ['hello?']);
    // The host's panel is open, so it was read straight away.
    expect(c.state.deliveryOf(c.state.bubbles.single), DeliveryState.read);
    expect(bodies(h), ['hello?']);
  });

  test('6: repeated hints and polling never duplicate messages', () async {
    final c = cubitFor(
      server,
      customer,
      peerUserId: host,
      callId: callId,
      pollInterval: const Duration(milliseconds: 10),
    );
    addTearDown(c.close);
    await c.start();
    final h = cubitFor(server, host, peerUserId: customer, callId: callId);
    addTearDown(h.close);
    await h.start();
    await h.send('one');
    await h.send('two');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(bodies(c), ['one', 'two']);
  });

  test('realtime down: the in-call poll still delivers', () async {
    final c = cubitFor(
      server,
      customer,
      peerUserId: host,
      callId: callId,
      pollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(c.close);
    await c.start();
    final h = cubitFor(server, host, peerUserId: customer, callId: callId);
    addTearDown(h.close);
    await h.start();
    server.realtimeDown = true;
    await h.send('missed hint');
    await settle();
    expect(bodies(c), isEmpty); // no hint arrived
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bodies(c), ['missed hint']);
  });

  test('7: interleaved messages from both sides stay in send order', () async {
    final (c, h) = await bothInCall();
    for (var i = 0; i < 6; i++) {
      await (i.isEven ? c : h).send('m$i');
    }
    await settle();
    const want = ['m0', 'm1', 'm2', 'm3', 'm4', 'm5'];
    expect(bodies(c), want);
    expect(bodies(h), want);
  });

  test('older pages load without gaps or repeats', () async {
    final (c, h) = await bothInCall();
    for (var i = 0; i < ConversationCubit.pageSize + 12; i++) {
      await h.send('p$i');
    }
    final fresh = cubitFor(
      server,
      customer,
      peerUserId: host,
      conversationId: c.state.conversationId,
      callId: callId, // a reconnecting panel pages the session
    );
    addTearDown(fresh.close);
    await fresh.start();
    expect(fresh.state.bubbles, hasLength(ConversationCubit.pageSize));
    await fresh.loadOlder();
    expect(bodies(fresh), [
      for (var i = 0; i < ConversationCubit.pageSize + 12; i++) 'p$i',
    ]);
    expect(fresh.state.hasOlder, isFalse);
  });

  test('8: someone outside the conversation cannot read it', () async {
    await bothInCall();
    final conv = server.conversationOf(customer, host);
    final stranger = cubitFor(
      server,
      'stranger',
      peerUserId: host,
      conversationId: conv,
    );
    addTearDown(stranger.close);
    await stranger.start();
    expect(stranger.state.status, ConversationStatus.failed);
    expect(stranger.state.bubbles, isEmpty);
  });

  test('9: after a block neither panel can send; nothing is stored', () async {
    final (c, h) = await bothInCall();
    await c.send('before block');
    server.block(host, customer);
    await c.send('after block');
    await h.send('host after block');
    final conv = server.conversationOf(customer, host);
    expect(server.stored(conv).map((m) => m.body), ['before block']);
    final rejected = c.state.bubbles.last;
    expect(c.state.deliveryOf(rejected), DeliveryState.notSent);
    expect(c.state.sendFailure?.code, 'blocked');

    // Re-opening is refused too (the in-call panel or the inbox).
    final reopened = cubitFor(
      server,
      customer,
      peerUserId: host,
      callId: callId,
    );
    addTearDown(reopened.close);
    await reopened.start();
    expect(reopened.state.status, ConversationStatus.failed);
    expect(reopened.state.failure?.code, 'blocked');
  });

  group('panel closed', () {
    test('counts unseen messages, previews the newest, does not mark read; '
        'opening clears and marks read', () async {
      final (c, h) = await bothInCall(customerVisible: false);
      server.markReadCalls.clear();
      await h.send('first');
      await h.send('second');
      await settle();
      expect(c.state.unseenCount, 2);
      expect(c.state.latestUnseen?.body, 'second');
      expect(server.markReadCalls, isNot(contains(customer)));
      // The host's messages are not read yet.
      expect(h.state.deliveryOf(h.state.bubbles.last), DeliveryState.sent);

      c.setVisible(true);
      await settle();
      expect(c.state.unseenCount, 0);
      expect(c.state.latestUnseen, isNull);
      expect(server.markReadCalls, contains(customer));
      // chat.read reached the host: read receipts update.
      expect(h.state.deliveryOf(h.state.bubbles.last), DeliveryState.read);
    });

    test('dismissPreview hides the preview but keeps the count', () async {
      final (c, h) = await bothInCall(customerVisible: false);
      await h.send('hi');
      await settle();
      c.dismissPreview();
      expect(c.state.latestUnseen, isNull);
      expect(c.state.unseenCount, 1);
    });

    test('own messages never count as unseen', () async {
      final (c, _) = await bothInCall(customerVisible: false);
      await c.send('mine');
      await settle();
      expect(c.state.unseenCount, 0);
    });
  });

  test('timestamps and senders are kept', () async {
    final (c, h) = await bothInCall();
    await c.send('a');
    await settle();
    final mine = c.state.bubbles.single;
    final theirs = h.state.bubbles.single;
    expect(mine.mine, isTrue);
    expect(theirs.mine, isFalse);
    expect(theirs.sentAt, mine.sentAt);
  });

  group('messages inside realtime hints', () {
    test(
      'a hinted message shows at once, before the API re-fetch returns',
      () async {
        final (c, h) = await bothInCall();
        // Every message-list request now takes "forever" (slow network).
        server.listGate = Completer<void>();
        await c.send('Quick hello');
        await settle();
        expect(bodies(h), ['Quick hello'], reason: 'shown from the hint');
        // The re-fetch then confirms it without a duplicate.
        server.listGate!.complete();
        server.listGate = null;
        await settle();
        expect(bodies(h), ['Quick hello']);
      },
    );

    test('an open inbox does not show an in-call message during the call; '
        'another call\'s panel does not either', () async {
      final (c, _) = await bothInCall();
      final conv = server.conversationOf(customer, host);
      final hostInbox = cubitFor(
        server,
        host,
        peerUserId: customer,
        conversationId: conv,
      );
      addTearDown(hostInbox.close);
      await hostInbox.start();
      final otherCall = cubitFor(
        server,
        host,
        peerUserId: customer,
        callId: 'call-2',
      );
      addTearDown(otherCall.close);
      await otherCall.start();

      await c.send('Only for this call');
      await settle();
      expect(bodies(hostInbox), isEmpty);
      expect(bodies(otherCall), isEmpty);
    });

    test('an older server (hint without the message) still delivers through '
        'the re-fetch', () async {
      server.hintsWithoutMessages = true;
      final (c, h) = await bothInCall();
      await c.send('Hello from an older server');
      await settle();
      expect(bodies(h), ['Hello from an older server']);
    });
  });
}
