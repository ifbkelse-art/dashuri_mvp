import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';

class _ListConv extends Mock implements ListConversations {}

class _ListMsg extends Mock implements ListMessages {}

class _Send extends Mock implements SendMessage {}

class _Start extends Mock implements StartConversation {}

class _Read extends Mock implements MarkConversationRead {}

class _Hints extends Mock implements WatchChatHints {}

class _Me extends Mock implements GetCurrentUserId {}

typedef SendInput = ({
  String conversationId,
  String body,
  IdempotencyKey idempotencyKey,
});
typedef ListInput = ({String conversationId, PageRequest page});

void main() {
  late _ListConv listConv;
  late _ListMsg listMsg;
  late _Send send;
  late _Start start;
  late _Read read;
  late _Hints hints;
  late _Me me;
  late StreamController<String> hintStream;

  setUpAll(() {
    registerFallbackValue(const PageRequest());
    registerFallbackValue(const NoInput());
    registerFallbackValue((conversationId: 'c', page: const PageRequest()));
    registerFallbackValue((
      conversationId: 'c',
      body: 'b',
      idempotencyKey: IdempotencyKey.generate(),
    ));
    registerFallbackValue((
      peerUserId: 'p',
      idempotencyKey: IdempotencyKey.generate(),
    ));
  });

  setUp(() {
    listConv = _ListConv();
    listMsg = _ListMsg();
    send = _Send();
    start = _Start();
    read = _Read();
    hints = _Hints();
    me = _Me();
    hintStream = StreamController<String>.broadcast();
    when(() => hints(any())).thenAnswer((_) => hintStream.stream);
    when(() => me(any())).thenAnswer((_) async => const Success('me'));
    when(() => read(any())).thenAnswer((_) async => const Success(null));
    when(
      () => listConv(any()),
    ).thenAnswer((_) async => Success(Page(items: [meera, kavya])));
  });
  tearDown(() => hintStream.close());

  group('ConversationsCubit', () {
    ConversationsCubit build() => ConversationsCubit(listConv, hints, me);

    blocTest<ConversationsCubit, ConversationsState>(
      'emits Loading then Failed when the use case fails',
      setUp: () => when(
        () => listConv(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (c) => c.load(),
      expect: () => const <ConversationsState>[
        ConversationsStateLoading(),
        ConversationsStateFailed(NetworkFailure()),
      ],
    );

    test('loads, then re-fetches on a chat.message hint', () async {
      final c = build();
      await c.load();
      expect((c.state as ConversationsStateLoaded).data.items, [meera, kavya]);
      expect((c.state as ConversationsStateLoaded).myUserId, 'me');
      hintStream.add('c1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(() => listConv(any())).called(2);
      await c.close();
    });

    test('loadMore appends the next page by cursor', () async {
      when(
        () => listConv(const PageRequest(limit: 30)),
      ).thenAnswer((_) async => Success(Page(items: [meera], nextCursor: 'n')));
      when(
        () => listConv(const PageRequest(cursor: 'n', limit: 30)),
      ).thenAnswer((_) async => Success(Page(items: [kavya])));
      final c = build();
      await c.load();
      await c.loadMore();
      final s = c.state as ConversationsStateLoaded;
      expect(s.data.items, [meera, kavya]);
      expect(s.data.hasMore, isFalse);
      await c.close();
    });
  });

  group('ConversationCubit', () {
    ConversationCubit build({
      String id = 'c1',
      String? peer,
      Conversation? known,
    }) => ConversationCubit(
      listMessages: listMsg,
      sendMessage: send,
      startConversation: start,
      markRead: read,
      listConversations: listConv,
      watchHints: hints,
      currentUserId: me,
      conversationId: id,
      peerUserId: peer,
      known: known,
      now: () => t0.add(const Duration(hours: 1)),
    );

    void newestPage(List<ChatMessage> items, {String? next}) => when(
      () => listMsg(
        any(
          that: isA<ListInput>().having((i) => i.page.cursor, 'cursor', isNull),
        ),
      ),
    ).thenAnswer((_) async => Success(Page(items: items, nextCursor: next)));

    test('opens: loads newest first, shows oldest first, marks read', () async {
      newestPage([msg('m2', minute: 2), msg('m1', sender: 'me', minute: 1)]);
      final c = build(known: meera);
      await c.start();
      expect(c.state.status, ConversationStatus.ready);
      expect(c.state.bubbles.map((b) => b.localId), ['m1', 'm2']);
      expect(c.state.bubbles.first.mine, isTrue);
      expect(c.state.peerName, 'Meera');
      verify(() => read('c1')).called(1);
      await c.close();
    });

    test('deep link without the inbox entry looks up the peer', () async {
      newestPage([]);
      final c = build();
      await c.start();
      expect(c.state.peerUserId, 'peer');
      expect(c.state.peerName, 'Meera');
      await c.close();
    });

    test('pages upward with the cursor', () async {
      newestPage([msg('m3', minute: 3)], next: 'older');
      when(
        () => listMsg(
          any(
            that: isA<ListInput>().having(
              (i) => i.page.cursor,
              'cursor',
              'older',
            ),
          ),
        ),
      ).thenAnswer(
        (_) async =>
            Success(Page(items: [msg('m2', minute: 2), msg('m1', minute: 1)])),
      );
      final c = build(known: meera);
      await c.start();
      await c.loadOlder();
      expect(c.state.bubbles.map((b) => b.localId), ['m1', 'm2', 'm3']);
      expect(c.state.hasOlder, isFalse);
      await c.close();
    });

    test(
      'new: starts the conversation (key reused on retry), then loads',
      () async {
        final keys = <String>[];
        var calls = 0;
        when(() => start(any())).thenAnswer((inv) async {
          keys.add(
            (inv.positionalArguments.first
                    as ({String peerUserId, IdempotencyKey idempotencyKey}))
                .idempotencyKey
                .value,
          );
          return calls++ == 0 ? const Err(NetworkFailure()) : Success(meera);
        });
        newestPage([]);
        final c = build(id: newConversationId, peer: 'peer');
        await c.start();
        expect(c.state.status, ConversationStatus.failed);
        await c.retry();
        expect(c.state.conversationId, 'c1');
        expect(c.state.status, ConversationStatus.ready);
        expect(keys.toSet(), hasLength(1));
        await c.close();
      },
    );

    test('new: messaging_not_allowed → restricted (CH04)', () async {
      when(() => start(any())).thenAnswer(
        (_) async => const Err(BusinessRuleFailure(code: messagingNotAllowed)),
      );
      final c = build(id: newConversationId, peer: 'peer');
      await c.start();
      expect(c.state.status, ConversationStatus.restricted);
      await c.close();
    });

    test('send: optimistic bubble replaced by the server message', () async {
      newestPage([]);
      final completer = Completer<Result<ChatMessage>>();
      when(() => send(any())).thenAnswer((_) => completer.future);
      final c = build(known: meera);
      await c.start();
      final sending = c.send('  Hello  ');
      expect(c.state.bubbles.single.status, BubbleStatus.sending);
      expect(c.state.bubbles.single.body, 'Hello');
      completer.complete(Success(msg('s1', sender: 'me', body: 'Hello')));
      await sending;
      expect(c.state.bubbles.single.status, BubbleStatus.sent);
      expect(c.state.bubbles.single.serverId, 's1');
      await c.close();
    });

    test('each message gets its own key; a retry reuses it', () async {
      newestPage([]);
      final keys = <String>[];
      var calls = 0;
      when(() => send(any())).thenAnswer((inv) async {
        keys.add(
          (inv.positionalArguments.first as SendInput).idempotencyKey.value,
        );
        return calls++ == 0
            ? const Err(NetworkFailure())
            : Success(msg('s$calls', sender: 'me'));
      });
      final c = build(known: meera);
      await c.start();
      await c.send('one');
      final failed = c.state.bubbles.single;
      expect(failed.status, BubbleStatus.failed);
      expect(c.state.sendFailure, const NetworkFailure());
      await c.retrySend(failed.localId);
      await c.send('two');
      expect(keys, hasLength(3));
      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[0]));
      expect(
        c.state.bubbles.every((b) => b.status == BubbleStatus.sent),
        isTrue,
      );
      await c.close();
    });

    test('message_rejected (CH05): not sent, notice, text kept', () async {
      newestPage([]);
      when(() => send(any())).thenAnswer(
        (_) async => const Err(
          BusinessRuleFailure(
            code: messageRejected,
            message: 'contact_details',
          ),
        ),
      );
      final c = build(known: meera);
      await c.start();
      final states = <ConversationState>[];
      final sub = c.stream.listen(states.add);
      await c.send('my number is 98204 12345');
      await Future<void>.delayed(Duration.zero);
      expect(c.state.bubbles.single.status, BubbleStatus.rejected);
      expect(c.state.filterNotice, isTrue);
      expect(
        states.map((s) => s.restoredDraft),
        contains('my number is 98204 12345'),
      );
      c.dismissFilterNotice();
      expect(c.state.filterNotice, isFalse);
      await sub.cancel();
      await c.close();
    });

    test('messaging_not_allowed on send → restricted', () async {
      newestPage([]);
      when(() => send(any())).thenAnswer(
        (_) async => const Err(BusinessRuleFailure(code: messagingNotAllowed)),
      );
      final c = build(known: meera);
      await c.start();
      await c.send('hi');
      expect(c.state.status, ConversationStatus.restricted);
      expect(c.state.bubbles, isEmpty);
      await c.close();
    });

    test('a hint for this conversation merges new messages', () async {
      var n = 0;
      when(() => listMsg(any())).thenAnswer(
        (_) async => Success(
          Page(
            items: n++ == 0 ? [msg('m1')] : [msg('m2', minute: 5), msg('m1')],
          ),
        ),
      );
      final c = build(known: meera);
      await c.start();
      hintStream
        ..add('other')
        ..add('c1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.state.bubbles.map((b) => b.localId), ['m1', 'm2']);
      verify(() => read('c1')).called(2);
      await c.close();
    });
  });
}
