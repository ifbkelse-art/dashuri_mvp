// EXPERIMENT — unified chat + in-call messaging, client side. Two users,
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

  test('1+2: a message sent during the call reaches the peer immediately '
      'and is in their normal chat', () async {
    final (c, h) = await bothInCall();
    await c.send('Can you hear me?');
    await settle();

    expect(bodies(h), ['Can you hear me?']);
    expect(h.state.bubbles.single.context, MessageContext.call);
    expect(c.state.bubbles.single.context, MessageContext.call);

    // The host's inbox opens the same conversation and sees it.
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
    expect(bodies(inbox), ['Can you hear me?']);
  });

  test('3+4: a normal-chat message sent while the call is active appears in '
      "the peer's in-call panel", () async {
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
    expect(bodies(c), ['Sent from the inbox']);
    expect(c.state.bubbles.single.context, MessageContext.chat);
  });

  test('history from before the call is in the in-call panel; one '
      'conversation per pair', () async {
    final before = cubitFor(server, customer, peerUserId: host);
    await before.start();
    await before.send('Hi before the call');
    await before.close();

    final (c, h) = await bothInCall();
    expect(bodies(c), ['Hi before the call']);
    expect(bodies(h), ['Hi before the call']);
    expect(c.state.conversationId, h.state.conversationId);
    expect(c.state.conversationId, server.conversationOf(customer, host));
  });

  test('5: history survives the end of the call; chatting continues', () async {
    final (c, h) = await bothInCall();
    await c.send('during the call');
    await h.send('reply during the call');
    await settle();
    // The call ends: the call screen closes its chat.
    await c.close();
    await h.close();

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
      expect(bodies(inbox), ['during the call', 'reply during the call']);
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
      'during the call',
      'reply during the call',
      'thanks for the call',
    ]);
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
}
