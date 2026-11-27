import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _MockListAvailableHosts extends Mock implements ListAvailableHosts {}

class _Home extends Mock implements GetDiscoveryHome {}

class _Profile extends Mock implements GetHostProfile {}

class _Repo extends Mock implements DiscoveryRepository {}

void main() {
  late _MockListAvailableHosts useCase;

  setUpAll(
    () => registerFallbackValue((
      page: const PageRequest(),
      filter: const DiscoveryFilter(),
    )),
  );
  setUp(() => useCase = _MockListAvailableHosts());

  blocTest<DiscoveryCubit, DiscoveryState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<Page<HostCard>>(NetworkFailure())),
    build: () => DiscoveryCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <DiscoveryState>[
      DiscoveryStateLoading(),
      DiscoveryStateFailed(NetworkFailure()),
    ],
  );

  blocTest<DiscoveryCubit, DiscoveryState>(
    'pages with the cursor and appends',
    setUp: () {
      when(
        () => useCase((
          page: const PageRequest(),
          filter: const DiscoveryFilter(),
        )),
      ).thenAnswer(
        (_) async => Success(Page(items: [host('a')], nextCursor: 'n1')),
      );
      when(
        () => useCase((
          page: const PageRequest(cursor: 'n1'),
          filter: const DiscoveryFilter(),
        )),
      ).thenAnswer((_) async => Success(Page(items: [host('b')])));
    },
    build: () => DiscoveryCubit(useCase),
    act: (c) async {
      await c.load();
      await c.loadMore();
      await c.loadMore(); // no more pages: ignored
    },
    expect: () => [
      const DiscoveryStateLoading(),
      DiscoveryStateLoaded(Page(items: [host('a')], nextCursor: 'n1')),
      DiscoveryStateLoaded(
        Page(items: [host('a')], nextCursor: 'n1'),
        const DiscoveryFilter(),
        true,
      ),
      DiscoveryStateLoaded(Page(items: [host('a'), host('b')])),
    ],
  );

  blocTest<DiscoveryCubit, DiscoveryState>(
    'a failed next page keeps the grid and flags the failure',
    setUp: () {
      when(
        () => useCase((
          page: const PageRequest(),
          filter: const DiscoveryFilter(),
        )),
      ).thenAnswer(
        (_) async => Success(Page(items: [host('a')], nextCursor: 'n1')),
      );
      when(
        () => useCase((
          page: const PageRequest(cursor: 'n1'),
          filter: const DiscoveryFilter(),
        )),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: () => DiscoveryCubit(useCase),
    act: (c) async {
      await c.load();
      await c.loadMore();
    },
    verify: (c) {
      final s = c.state as DiscoveryStateLoaded;
      expect(s.loadMoreFailed, isTrue);
      expect(s.data.items, hasLength(1));
    },
  );

  blocTest<DiscoveryCubit, DiscoveryState>(
    'language chip and sort re-query with the filter',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Success(Page<HostCard>(items: []))),
    build: () => DiscoveryCubit(useCase),
    act: (c) async {
      await c.setLanguage('hi');
      await c.setSort(DiscoverySort.rateLow);
      await c.clearFilters();
    },
    verify: (c) {
      final calls = verify(
        () => useCase(captureAny()),
      ).captured.cast<HostQuery>().map((q) => q.filter).toList();
      expect(calls[0], const DiscoveryFilter(language: 'hi'));
      expect(
        calls[1],
        const DiscoveryFilter(language: 'hi', sort: DiscoverySort.rateLow),
      );
      expect(calls[2], const DiscoveryFilter(sort: DiscoverySort.rateLow));
      expect(calls[1].toQuery(), {'language': 'hi', 'sort': 'rate_low'});
    },
  );

  test('a stale response for an old filter is dropped', () async {
    final slow = Completer<Result<Page<HostCard>>>();
    when(
      () =>
          useCase((page: const PageRequest(), filter: const DiscoveryFilter())),
    ).thenAnswer((_) => slow.future);
    when(
      () => useCase((
        page: const PageRequest(),
        filter: const DiscoveryFilter(language: 'ta'),
      )),
    ).thenAnswer((_) async => Success(Page(items: [host('t')])));
    final c = DiscoveryCubit(useCase);
    final first = c.load();
    await c.setLanguage('ta');
    slow.complete(Success(Page(items: [host('old')])));
    await first;
    expect((c.state as DiscoveryStateLoaded).data.items.single.userId, 't');
    await c.close();
  });

  group('DiscoveryHeaderCubit', () {
    blocTest<DiscoveryHeaderCubit, DiscoveryHeaderState>(
      'loads the home header and dismisses the free call banner',
      build: () {
        final h = _Home();
        when(() => h(true)).thenAnswer(
          (_) async => const Success(
            DiscoveryHome(availableDiamonds: 0, freeCallAvailable: true),
          ),
        );
        return DiscoveryHeaderCubit(h, freeCallSupported: true);
      },
      act: (c) async {
        await c.load();
        expect(c.state.showFreeCall, isTrue);
        c.dismissFreeCall();
      },
      verify: (c) => expect(c.state.showFreeCall, isFalse),
    );

    // Regression (2026-11-27): the header lives in an IndexedStack shell and
    // loaded once, so after buying Diamonds (or a call/gift) the balance pill
    // kept the old number. A wallet.updated hint now re-reads it.
    test(
      're-reads the balance when the server says the wallet changed',
      () async {
        final h = _Home();
        final repo = _Repo();
        final hints = StreamController<void>.broadcast();
        when(repo.walletUpdates).thenAnswer((_) => hints.stream);
        var balance = 100;
        when(() => h(true)).thenAnswer(
          (_) async => Success(DiscoveryHome(availableDiamonds: balance)),
        );
        final c = DiscoveryHeaderCubit(
          h,
          freeCallSupported: true,
          watchBalance: WatchBalanceChanges(repo),
        );
        await c.load();
        expect(c.state.home.availableDiamonds, 100);

        balance = 4100;
        final next = c.stream.firstWhere(
          (s) => s.home.availableDiamonds == 4100,
        );
        hints.add(null);
        await next.timeout(const Duration(seconds: 1));
        expect(c.state.home.availableDiamonds, 4100);

        // Loading again does not stack a second subscription.
        await c.load();
        clearInteractions(h);
        hints.add(null);
        await Future<void>.delayed(Duration.zero);
        verify(() => h(true)).called(1);

        await c.close();
        expect(hints.hasListener, isFalse);
        await hints.close();
      },
    );
  });

  group('GetDiscoveryHome', () {
    test('tolerates partial failures and skips the card on iOS', () async {
      final r = _Repo();
      when(
        r.myDisplayName,
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      when(r.availableDiamonds).thenAnswer((_) async => const Success(12480));
      when(r.onlineCount).thenAnswer((_) async => const Success(128));
      when(
        r.freeCallCardStatus,
      ).thenAnswer((_) async => const Success('available'));
      final ios = await GetDiscoveryHome(r)(false);
      expect(
        (ios as Success<DiscoveryHome>).value,
        const DiscoveryHome(availableDiamonds: 12480, onlineCount: 128),
      );
      verifyNever(r.freeCallCardStatus);
      final android = await GetDiscoveryHome(r)(true);
      expect(
        (android as Success<DiscoveryHome>).value.freeCallAvailable,
        isTrue,
      );
    });
  });

  group('HostProfileCubit', () {
    final view = (
      profile: HostProfile(card: host('a')),
      balance: 12480,
      approxPaisePerDiamondMilli: 2200,
    );
    blocTest<HostProfileCubit, HostProfileState>(
      'loads with the ₹ estimate and talk time',
      build: () {
        final p = _Profile();
        when(() => p('a')).thenAnswer((_) async => Success(view));
        return HostProfileCubit(p);
      },
      act: (c) => c.load('a'),
      verify: (c) {
        final s = c.state as HostProfileLoaded;
        expect(s.approxPaisePerMinute, 5280);
        expect(s.talkTimeSeconds, 312);
      },
    );

    blocTest<HostProfileCubit, HostProfileState>(
      'blocked or missing host fails with not found',
      build: () {
        final p = _Profile();
        when(
          () => p('a'),
        ).thenAnswer((_) async => const Err(NotFoundFailure()));
        return HostProfileCubit(p);
      },
      act: (c) => c.load('a'),
      expect: () => const [
        HostProfileLoading(),
        HostProfileFailed(NotFoundFailure()),
      ],
    );

    test('GetHostProfile keeps the host when optional reads fail', () async {
      final r = _Repo();
      when(
        () => r.getHost('a'),
      ).thenAnswer((_) async => Success(HostProfile(card: host('a'))));
      when(
        r.availableDiamonds,
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      when(
        r.approxPaisePerDiamondMilli,
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final res = await GetHostProfile(r)('a');
      final v = (res as Success<HostProfileView>).value;
      expect(v.balance, isNull);
      expect(v.approxPaisePerDiamondMilli, isNull);
    });
  });
}
