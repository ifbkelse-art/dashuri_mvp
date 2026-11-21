import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  setUpAll(registerHostFallbacks);

  group('HostEarningsCubit', () {
    late MockGetEarnings getEarnings;
    setUp(() => getEarnings = MockGetEarnings());

    blocTest<HostEarningsCubit, HostEarningsState>(
      'loaded',
      setUp: () => when(
        () => getEarnings(any()),
      ).thenAnswer((_) async => Success(sampleEarnings)),
      build: () => HostEarningsCubit(getEarnings),
      act: (c) => c.load(),
      expect: () => [
        const HostEarningsState(),
        HostEarningsState(
          status: HostEarningsStatus.loaded,
          earnings: sampleEarnings,
        ),
      ],
    );

    blocTest<HostEarningsCubit, HostEarningsState>(
      'failed',
      setUp: () => when(
        () => getEarnings(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => HostEarningsCubit(getEarnings),
      act: (c) => c.load(),
      expect: () => const [
        HostEarningsState(),
        HostEarningsState(
          status: HostEarningsStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  group('HostPayoutsCubit', () {
    late MockListWithdrawals list;
    setUp(() => list = MockListWithdrawals());

    blocTest<HostPayoutsCubit, PagedListState<Withdrawal>>(
      'loads and pages with the cursor',
      setUp: () {
        when(() => list(const PageRequest())).thenAnswer(
          (_) async =>
              Success(Page(items: [sampleWithdrawal], nextCursor: 'n1')),
        );
        when(
          () => list(const PageRequest(cursor: 'n1')),
        ).thenAnswer((_) async => Success(Page(items: [sampleWithdrawal])));
      },
      build: () => HostPayoutsCubit(list),
      act: (c) async {
        await c.load();
        await c.loadMore();
        await c.loadMore(); // no more pages: no call
      },
      expect: () => [
        const PagedListState<Withdrawal>(),
        PagedListState(
          status: PagedStatus.loaded,
          items: [sampleWithdrawal],
          nextCursor: 'n1',
        ),
        PagedListState(
          status: PagedStatus.loaded,
          items: [sampleWithdrawal],
          nextCursor: 'n1',
          loadingMore: true,
        ),
        PagedListState(
          status: PagedStatus.loaded,
          items: [sampleWithdrawal, sampleWithdrawal],
        ),
      ],
      verify: (_) => verify(() => list(any())).called(2),
    );

    blocTest<HostPayoutsCubit, PagedListState<Withdrawal>>(
      'load more failure keeps the items',
      setUp: () {
        when(() => list(const PageRequest())).thenAnswer(
          (_) async =>
              Success(Page(items: [sampleWithdrawal], nextCursor: 'n1')),
        );
        when(
          () => list(const PageRequest(cursor: 'n1')),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
      },
      build: () => HostPayoutsCubit(list),
      act: (c) async {
        await c.load();
        await c.loadMore();
      },
      verify: (c) {
        expect(c.state.items, [sampleWithdrawal]);
        expect(c.state.loadMoreFailure, const NetworkFailure());
      },
    );
  });

  group('HostCallsCubit', () {
    late MockListHostCalls list;
    final paid = sampleCall();
    final free = sampleCall(id: 'c2', free: true, seconds: 60, beans: 2000);
    final missed = sampleCall(
      id: 'c3',
      phase: 'missed',
      seconds: 0,
      beans: null,
    );
    setUp(() => list = MockListHostCalls());

    blocTest<HostCallsCubit, HostCallsState>(
      'loads and filters on the client',
      setUp: () => when(
        () => list(any()),
      ).thenAnswer((_) async => Success(Page(items: [paid, free, missed]))),
      build: () => HostCallsCubit(list),
      act: (c) async {
        await c.load();
        c.setFilter(HostCallFilter.paid);
        expect(c.state.visible, [paid]);
        c.setFilter(HostCallFilter.free);
        expect(c.state.visible, [free]);
        c.setFilter(HostCallFilter.missed);
        expect(c.state.visible, [missed]);
        c.setFilter(HostCallFilter.all);
      },
      verify: (c) => expect(c.state.visible, hasLength(3)),
    );

    blocTest<HostCallsCubit, HostCallsState>(
      'failure',
      setUp: () => when(
        () => list(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => HostCallsCubit(list),
      act: (c) => c.load(),
      verify: (c) => expect(c.state.list.status, PagedStatus.failed),
    );
  });

  group('HostProfileTabCubit', () {
    late MockGetMyHostProfile getProfile;
    late MockGetHostStatus getStatus;
    late MockSetAvailability setAvailability;
    late HostPresenceController presence;
    late FakeTimers timers;

    setUp(() {
      getProfile = MockGetMyHostProfile();
      getStatus = MockGetHostStatus();
      setAvailability = MockSetAvailability();
      timers = FakeTimers();
      final heartbeat = MockSendHeartbeat();
      when(() => heartbeat(any())).thenAnswer((_) async => const Success(null));
      presence = HostPresenceController(heartbeat, timerFactory: timers.call);
      when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Success(sampleProfile));
    });
    tearDown(() => presence.dispose());

    HostProfileTabCubit build() =>
        HostProfileTabCubit(getProfile, getStatus, setAvailability, presence);

    blocTest<HostProfileTabCubit, HostProfileTabState>(
      'switching to customer goes offline first, stops heartbeats, then calls back',
      setUp: () {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => Success(approvedOnline));
        when(
          () => setAvailability(false),
        ).thenAnswer((_) async => const Success(approvedOffline));
      },
      build: build,
      act: (c) async {
        await c.load();
        presence.setOnline(online: true);
        var called = false;
        final ok = await c.switchToCustomer(() async => called = true);
        expect(ok, isTrue);
        expect(called, isTrue);
      },
      verify: (_) {
        verify(() => setAvailability(false)).called(1);
        expect(presence.isBeating, isFalse);
      },
    );

    blocTest<HostProfileTabCubit, HostProfileTabState>(
      'does not switch when going offline fails',
      setUp: () {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => Success(approvedOnline));
        when(
          () => setAvailability(false),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
      },
      build: build,
      act: (c) async {
        await c.load();
        var called = false;
        final ok = await c.switchToCustomer(() async => called = true);
        expect(ok, isFalse);
        expect(called, isFalse);
      },
      verify: (c) => expect(c.state.failure, const NetworkFailure()),
    );

    blocTest<HostProfileTabCubit, HostProfileTabState>(
      'load failure',
      setUp: () => when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (c) => c.load(),
      verify: (c) => expect(c.state.status, HostProfileTabStatus.failed),
    );
  });
}
