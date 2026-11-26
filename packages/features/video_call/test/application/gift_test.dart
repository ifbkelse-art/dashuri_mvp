import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Catalogue extends Mock implements GetGiftCatalogue {}

class _Balance extends Mock implements GetGiftBalance {}

class _Send extends Mock implements SendGift {}

class _History extends Mock implements GetCallGifts {}

class _Watch extends Mock implements WatchCallGifts {}

const rose = Gift(
  id: 'rose',
  name: 'Rose',
  emoji: '🌹',
  tier: GiftTier.common,
  diamondPrice: 1500,
);
const teddy = Gift(
  id: 'teddy',
  name: 'Teddy',
  emoji: '🧸',
  tier: GiftTier.common,
  diamondPrice: 5000,
);

GiftEvent event(String id, {DateTime? at, String gift = 'Rose'}) => GiftEvent(
  giftTransactionId: id,
  giftId: gift.toLowerCase(),
  giftName: gift,
  emoji: '🌹',
  tier: GiftTier.common,
  diamondValue: 1500,
  senderId: 'u1',
  senderName: 'Asha',
  recipientId: 'h1',
  recipientName: 'Meera',
  callId: 'c1',
  sentAt: at ?? DateTime.now().toUtc(),
);

GiftReceipt receipt(String id, int balance) =>
    GiftReceipt(event: event(id), availableDiamonds: balance, replayed: false);

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

  group('GiftSheetBloc', () {
    late _Catalogue catalogue;
    late _Balance balance;
    late _Send send;
    var keys = <String>[];

    GiftSheetBloc build() {
      keys = [];
      return GiftSheetBloc(
        catalogue: catalogue,
        balance: balance,
        send: send,
        newKey: () {
          final k = IdempotencyKey.generate();
          keys.add(k.value);
          return k;
        },
      );
    }

    setUp(() {
      catalogue = _Catalogue();
      balance = _Balance();
      send = _Send();
      when(
        () => catalogue(any()),
      ).thenAnswer((_) async => const Success([rose, teddy]));
      when(() => balance(any())).thenAnswer((_) async => const Success(4000));
    });

    Future<GiftSheetBloc> opened() async {
      final b = build()
        ..add(const GiftSheetOpened(callId: 'c1', recipientUserId: 'h1'));
      await Future<void>.delayed(Duration.zero);
      return b;
    }

    test('loads catalogue and balance; nothing selected', () async {
      final b = await opened();
      expect(b.state.load, GiftLoadStatus.ready);
      expect(b.state.gifts, [rose, teddy]);
      expect(b.state.balance, 4000);
      expect(b.state.canSend, isFalse);
      await b.close();
    });

    test('insufficient balance: display state, no request sent', () async {
      final b = await opened();
      b.add(const GiftSelected('teddy'));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.insufficient, isTrue);
      expect(b.state.canSend, isFalse);
      b.add(const GiftSendPressed());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.failure?.code, 'insufficient_diamonds');
      verifyNever(() => send(any()));
      await b.close();
    });

    test('success uses the server balance and counts the send', () async {
      when(
        () => send(any()),
      ).thenAnswer((_) async => Success(receipt('g1', 2500)));
      final b = await opened();
      b
        ..add(const GiftSelected('rose'))
        ..add(const GiftSendPressed());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.send, GiftSendStatus.sent);
      expect(b.state.balance, 2500);
      expect(b.state.sentCount, 1);
      expect(b.state.lastReceipt?.event.giftTransactionId, 'g1');
      final input =
          verify(() => send(captureAny())).captured.single as SendGiftInput;
      expect(input.giftId, 'rose');
      expect(input.recipientUserId, 'h1');
      await b.close();
    });

    test('repeated taps while sending send once', () async {
      final gate = Completer<Result<GiftReceipt>>();
      when(() => send(any())).thenAnswer((_) => gate.future);
      final b = await opened();
      b
        ..add(const GiftSelected('rose'))
        ..add(const GiftSendPressed())
        ..add(const GiftSendPressed())
        ..add(const GiftSendPressed());
      await Future<void>.delayed(Duration.zero);
      gate.complete(Success(receipt('g1', 2500)));
      await Future<void>.delayed(Duration.zero);
      verify(() => send(any())).called(1);
      await b.close();
    });

    test(
      'unknown outcome (offline/timeout): retry reuses the same key',
      () async {
        var n = 0;
        when(() => send(any())).thenAnswer((_) async {
          n++;
          return n == 1
              ? const Err(NetworkFailure())
              : Success(receipt('g1', 2500));
        });
        final b = await opened();
        b
          ..add(const GiftSelected('rose'))
          ..add(const GiftSendPressed());
        await Future<void>.delayed(Duration.zero);
        expect(b.state.send, GiftSendStatus.failed);
        b.add(const GiftSendPressed());
        await Future<void>.delayed(Duration.zero);
        final sent = verify(
          () => send(captureAny()),
        ).captured.cast<SendGiftInput>();
        expect(sent, hasLength(2));
        expect(sent[0].idempotencyKey.value, sent[1].idempotencyKey.value);
        expect(keys, hasLength(1));
        await b.close();
      },
    );

    test(
      'definite refusal discards the key; a new selection gets a new key',
      () async {
        when(() => send(any())).thenAnswer(
          (_) async => const Err(BusinessRuleFailure(code: 'gift_unavailable')),
        );
        final b = await opened();
        b
          ..add(const GiftSelected('rose'))
          ..add(const GiftSendPressed());
        await Future<void>.delayed(Duration.zero);
        b.add(const GiftSendPressed());
        await Future<void>.delayed(Duration.zero);
        expect(keys, hasLength(2));
        await b.close();
      },
    );

    test('call ended: refusal disables gifting', () async {
      when(() => send(any())).thenAnswer(
        (_) async => const Err(BusinessRuleFailure(code: 'call_not_giftable')),
      );
      final b = await opened();
      b
        ..add(const GiftSelected('rose'))
        ..add(const GiftSendPressed());
      await Future<void>.delayed(Duration.zero);
      expect(b.state.callEligible, isFalse);
      expect(b.state.canSend, isFalse);
      await b.close();
    });

    blocTest<GiftSheetBloc, GiftSheetState>(
      'catalogue failure is shown with retry',
      setUp: () => when(
        () => catalogue(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (b) =>
          b.add(const GiftSheetOpened(callId: 'c1', recipientUserId: 'h1')),
      verify: (b) {
        expect(b.state.load, GiftLoadStatus.failed);
        expect(b.state.failure, isA<NetworkFailure>());
      },
    );

    test('ineligible call: Send does nothing', () async {
      final b = await opened();
      b
        ..add(const GiftSelected('rose'))
        ..add(const GiftCallEligibilityChanged(eligible: false))
        ..add(const GiftSendPressed());
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => send(any()));
      await b.close();
    });
  });

  group('GiftCelebrationCubit', () {
    late _History history;
    late _Watch watch;
    // Closed in tearDown.
    // ignore: close_sinks
    late StreamController<GiftEvent> live;
    late List<(Duration, void Function())> timers;
    var now = DateTime.utc(2026, 11, 26, 12);

    GiftCelebrationCubit build() => GiftCelebrationCubit(
      history: history,
      watch: watch,
      now: () => now,
      timer: (d, f) {
        timers.add((d, f));
        return Timer(const Duration(days: 1), () {});
      },
    );

    void fireTimer() => timers.removeAt(0).$2();

    setUp(() {
      history = _History();
      watch = _Watch();
      live = StreamController<GiftEvent>.broadcast();
      timers = [];
      now = DateTime.utc(2026, 11, 26, 12);
      when(() => watch(any())).thenAnswer((_) => live.stream);
      when(() => history(any())).thenAnswer((_) async => const Success([]));
    });
    tearDown(() => live.close());

    test('gifts already in the history are not replayed on open', () async {
      when(() => history(any())).thenAnswer(
        (_) async => Success([event('old1', at: now), event('old2', at: now)]),
      );
      final c = build();
      await c.start('c1');
      c.offer(event('old1'));
      expect(c.state.current, isNull);
      expect(timers, isEmpty);
      await c.close();
    });

    test('one celebration at a time, in order, each once', () async {
      final c = build();
      await c.start('c1');
      live
        ..add(event('g1'))
        ..add(event('g2'))
        ..add(event('g1')); // duplicate delivery
      await Future<void>.delayed(Duration.zero);
      c.offer(event('g2')); // the sender's receipt for an already-seen gift
      expect(c.state.current?.giftTransactionId, 'g1');
      expect(c.state.pending, 1);
      expect(timers.single.$1, const Duration(seconds: 5));
      fireTimer();
      expect(c.state.current?.giftTransactionId, 'g2');
      fireTimer();
      expect(c.state.current, isNull);
      expect(c.state.sequence, 2);
      await c.close();
    });

    test('long queues are shortened, never dropped', () async {
      final c = build();
      await c.start('c1');
      for (var i = 0; i < 10; i++) {
        c.offer(event('g$i'));
      }
      expect(c.state.compact, isTrue);
      var shown = 1;
      while (c.state.current != null) {
        fireTimer();
        if (c.state.current != null) shown++;
      }
      expect(shown, 10);
      await c.close();
    });

    test('reconnect: recent missed gifts celebrate, old ones do not', () async {
      final c = build();
      await c.start('c1');
      when(() => history(any())).thenAnswer(
        (_) async => Success([
          event('stale', at: now.subtract(const Duration(minutes: 2))),
          event('fresh', at: now.subtract(const Duration(seconds: 5))),
        ]),
      );
      await c.resync();
      expect(c.state.current?.giftTransactionId, 'fresh');
      expect(c.state.pending, 0);
      fireTimer();
      await c.resync(); // a second reconnect replays nothing
      expect(c.state.current, isNull);
      await c.close();
    });

    test('animation failure: finished() moves on', () async {
      final c = build();
      await c.start('c1');
      c
        ..offer(event('g1'))
        ..offer(event('g2'))
        ..finished();
      expect(c.state.current?.giftTransactionId, 'g2');
      await c.close();
    });

    test('events of another call are ignored', () async {
      final c = build();
      await c.start('c1');
      c.offer(
        GiftEvent(
          giftTransactionId: 'x',
          giftId: 'rose',
          giftName: 'Rose',
          emoji: '🌹',
          tier: GiftTier.common,
          diamondValue: 1500,
          senderId: 'u1',
          senderName: 'A',
          recipientId: 'h1',
          recipientName: 'M',
          callId: 'other',
          sentAt: now,
        ),
      );
      expect(c.state.current, isNull);
      await c.close();
    });
  });
}
