import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _Info extends Mock implements GetPreCallInfo {}

class _Request extends Mock implements RequestCall {}

class _Get extends Mock implements GetCall {}

class _Balance extends Mock implements GetAvailableDiamonds {}

class _History extends Mock implements GetCallHistory {}

class _WatchIncoming extends Mock implements WatchIncomingCalls {}

const _info = PreCallInfo(
  hostUserId: 'h1',
  hostName: 'Ananya',
  ratePerMinute: 2400,
  availability: 'available',
  availableDiamonds: 12480,
  approxPaisePerDiamondMilli: 2200,
);

void main() {
  setUpAll(() {
    registerFallbackValue((
      hostUserId: '',
      idempotencyKey: IdempotencyKey.generate(),
    ));
    registerFallbackValue(const NoInput());
    registerFallbackValue(const PageRequest());
  });

  group('PreCallInfo', () {
    test('approximation and talk time', () {
      expect(_info.approxPaisePerMinute, 5280);
      expect(_info.talkTimeSeconds, 312);
      expect(_info.hasMinimumBalance, isTrue);
    });
  });

  group('PreCallCubit', () {
    late _Info info;
    late _Request request;
    setUp(() {
      info = _Info();
      request = _Request();
      when(() => info('h1')).thenAnswer((_) async => const Success(_info));
    });

    blocTest<PreCallCubit, PreCallState>(
      'loads then starts the call',
      setUp: () => when(
        () => request(any()),
      ).thenAnswer((_) async => Success(session(phase: CallPhase.ringing))),
      build: () => PreCallCubit(getInfo: info, requestCall: request),
      act: (c) async {
        await c.load('h1');
        await c.startCall();
      },
      expect: () => [
        const PreCallLoading(),
        const PreCallReady(_info),
        const PreCallReady(_info, requesting: true),
        PreCallStarted(session(phase: CallPhase.ringing)),
      ],
    );

    blocTest<PreCallCubit, PreCallState>(
      'server insufficient_diamonds shows V06',
      setUp: () => when(() => request(any())).thenAnswer(
        (_) async =>
            const Err(BusinessRuleFailure(code: 'insufficient_diamonds')),
      ),
      build: () => PreCallCubit(getInfo: info, requestCall: request),
      act: (c) async {
        await c.load('h1');
        await c.startCall();
      },
      verify: (c) => expect((c.state as PreCallReady).insufficient, isTrue),
    );

    blocTest<PreCallCubit, PreCallState>(
      'retry after a network error reuses the idempotency key',
      setUp: () => when(
        () => request(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => PreCallCubit(getInfo: info, requestCall: request),
      act: (c) async {
        await c.load('h1');
        await c.startCall();
        await c.startCall();
      },
      verify: (_) {
        final keys = verify(() => request(captureAny())).captured
            .cast<({String hostUserId, IdempotencyKey idempotencyKey})>()
            .map((r) => r.idempotencyKey.value)
            .toSet();
        expect(keys, hasLength(1));
      },
    );

    blocTest<PreCallCubit, PreCallState>(
      'below 60 s of balance never requests',
      setUp: () => when(() => info('h1')).thenAnswer(
        (_) async => const Success(
          PreCallInfo(
            hostUserId: 'h1',
            hostName: 'A',
            ratePerMinute: 4500,
            availability: 'available',
            availableDiamonds: 1150,
          ),
        ),
      ),
      build: () => PreCallCubit(getInfo: info, requestCall: request),
      act: (c) async {
        await c.load('h1');
        await c.startCall();
      },
      verify: (_) => verifyNever(() => request(any())),
    );
  });

  group('CallSummaryCubit', () {
    blocTest<CallSummaryCubit, CallSummaryState>(
      'loads the session and the remaining balance',
      build: () {
        final get = _Get(), bal = _Balance();
        when(
          () => get('c1'),
        ).thenAnswer((_) async => Success(session(phase: CallPhase.ended)));
        when(() => bal(any())).thenAnswer((_) async => const Success(5080));
        return CallSummaryCubit(getCall: get, getBalance: bal);
      },
      act: (c) => c.load('c1'),
      expect: () => [
        const CallSummaryLoading(),
        CallSummaryLoaded(session(phase: CallPhase.ended), balance: 5080),
      ],
    );

    blocTest<CallSummaryCubit, CallSummaryState>(
      'fails when the call cannot be read',
      build: () {
        final get = _Get();
        when(
          () => get('c1'),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        return CallSummaryCubit(getCall: get, getBalance: _Balance());
      },
      act: (c) => c.load('c1'),
      expect: () => const [
        CallSummaryLoading(),
        CallSummaryFailed(NetworkFailure()),
      ],
    );
  });

  group('CallHistoryCubit', () {
    blocTest<CallHistoryCubit, CallHistoryState>(
      'pages with the cursor',
      build: () {
        final h = _History();
        when(() => h(const PageRequest())).thenAnswer(
          (_) async => Success(Page(items: [session()], nextCursor: 'n')),
        );
        when(
          () => h(const PageRequest(cursor: 'n')),
        ).thenAnswer((_) async => Success(Page(items: [session(billed: 5)])));
        return CallHistoryCubit(h);
      },
      act: (c) async {
        await c.load();
        await c.loadMore();
      },
      verify: (c) {
        final s = c.state as CallHistoryLoaded;
        expect(s.items, hasLength(2));
        expect(s.hasMore, isFalse);
      },
    );
  });

  group('IncomingCallCubit', () {
    test('reports each ringing call once', () async {
      final w = _WatchIncoming();
      final controller = StreamController<CallSession>();
      when(() => w(any())).thenAnswer((_) => controller.stream);
      final cubit = IncomingCallCubit(w)..start();
      final ring = session(role: CallRole.receiver, phase: CallPhase.ringing);
      controller
        ..add(ring)
        ..add(ring);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const IncomingCallState(callId: 'c1', sequence: 1));
      await cubit.close();
      await controller.close();
    });

    group('backup check (a missed realtime message must not lose a call)', () {
      late _WatchIncoming w;
      late _History h;
      late bool expecting;
      setUp(() {
        w = _WatchIncoming();
        h = _History();
        expecting = true;
        // Realtime delivers nothing at all.
        when(() => w(any())).thenAnswer((_) => const Stream.empty());
      });

      IncomingCallCubit build({Duration every = const Duration(hours: 1)}) =>
          IncomingCallCubit(
            w,
            recentCalls: h,
            gate: IncomingCallCheckGate(() => expecting),
            backupInterval: every,
          )..start();

      test('reports a ringing call for me found in recent calls', () async {
        when(() => h(any())).thenAnswer(
          (_) async => Success(
            Page(
              items: [
                session(role: CallRole.receiver, phase: CallPhase.ringing),
              ],
            ),
          ),
        );
        final cubit = build();
        await cubit.checkNow();
        expect(cubit.state, const IncomingCallState(callId: 'c1', sequence: 1));
        await cubit.checkNow(); // the same call is reported once
        expect(cubit.state.sequence, 1);
        await cubit.close();
      });

      test(
        'ignores my own outgoing call and calls no longer ringing',
        () async {
          when(() => h(any())).thenAnswer(
            (_) async => Success(
              Page(
                items: [
                  session(role: CallRole.caller, phase: CallPhase.ringing),
                  session(role: CallRole.receiver, phase: CallPhase.ended),
                ],
              ),
            ),
          );
          final cubit = build();
          await cubit.checkNow();
          expect(cubit.state, const IncomingCallState());
          await cubit.close();
        },
      );

      test(
        'does not check when the gate is closed (not an online host)',
        () async {
          expecting = false;
          final cubit = build();
          await cubit.checkNow();
          verifyNever(() => h(any()));
          await cubit.close();
        },
      );

      test('checks periodically on its own', () async {
        when(() => h(any())).thenAnswer(
          (_) async => Success(
            Page(
              items: [
                session(role: CallRole.receiver, phase: CallPhase.ringing),
              ],
            ),
          ),
        );
        final cubit = build(every: const Duration(milliseconds: 10));
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(cubit.state.callId, 'c1');
        await cubit.close();
      });

      test('a failed check is ignored', () async {
        when(() => h(any())).thenAnswer(
          (_) async => const Err(NetworkFailure(message: 'offline')),
        );
        final cubit = build();
        await cubit.checkNow();
        expect(cubit.state, const IncomingCallState());
        await cubit.close();
      });
    });
  });
}
