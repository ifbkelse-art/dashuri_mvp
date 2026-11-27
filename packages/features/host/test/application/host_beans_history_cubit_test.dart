import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

BeanHistoryItem line(String id, {int beans = 100, int balance = 100}) =>
    BeanHistoryItem(
      id: id,
      occurredAt: DateTime.utc(2026, 11, 28, 12),
      type: BeanLineType.call,
      title: 'Call with Bruce',
      beans: beans,
      balanceAfter: balance,
    );

const summary = BeanSummary(
  balance: 5957,
  onHold: 5798,
  available: 159,
  pendingPayout: 40,
  lifetimeEarned: 6497,
  fromCalls: 599,
  fromGifts: 3898,
  fromFreeCalls: 2000,
  reversed: 100,
  paidOut: 400,
  earnedToday: 4217,
  earned7Days: 6497,
  earned30Days: 6497,
);

void main() {
  setUpAll(registerHostFallbacks);

  late MockGetBeanHistory history;
  late MockGetBeanSummary sum;
  setUp(() {
    history = MockGetBeanHistory();
    sum = MockGetBeanSummary();
    when(() => sum(any())).thenAnswer((_) async => const Success(summary));
  });

  HostBeansHistoryCubit build() => HostBeansHistoryCubit(history, sum);

  blocTest<HostBeansHistoryCubit, HostBeansHistoryState>(
    'load: header and first page together',
    setUp: () => when(() => history(any())).thenAnswer(
      (_) async => Success(Page(items: [line('a')], nextCursor: 'n1')),
    ),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const HostBeansHistoryState(),
      isA<HostBeansHistoryState>()
          .having((s) => s.summary, 'summary', summary)
          .having((s) => s.list.status, 'status', PagedStatus.loaded)
          .having((s) => s.list.items.length, 'items', 1)
          .having((s) => s.list.nextCursor, 'cursor', 'n1'),
    ],
  );

  blocTest<HostBeansHistoryCubit, HostBeansHistoryState>(
    'a failed list still shows the header',
    setUp: () => when(
      () => history(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (c) => c.load(),
    skip: 1,
    expect: () => [
      isA<HostBeansHistoryState>()
          .having((s) => s.summary, 'summary', summary)
          .having((s) => s.list.status, 'status', PagedStatus.failed),
    ],
  );

  blocTest<HostBeansHistoryCubit, HostBeansHistoryState>(
    'a failed header never blocks the list',
    setUp: () {
      when(
        () => sum(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      when(
        () => history(any()),
      ).thenAnswer((_) async => Success(Page(items: [line('a')])));
    },
    build: build,
    act: (c) => c.load(),
    skip: 1,
    expect: () => [
      isA<HostBeansHistoryState>()
          .having((s) => s.summary, 'summary', isNull)
          .having((s) => s.summaryFailure, 'failure', isNotNull)
          .having((s) => s.list.items.length, 'items', 1),
    ],
  );

  test(
    'setFilter asks the server for that filter and keeps the header',
    () async {
      when(
        () => history(any()),
      ).thenAnswer((_) async => Success(Page(items: [line('a')])));
      final c = build();
      await c.load();
      when(
        () => history(any()),
      ).thenAnswer((_) async => Success(Page(items: [line('g1'), line('g2')])));
      await c.setFilter(BeanFilter.gifts);
      final query =
          verify(() => history(captureAny())).captured.last as BeanHistoryQuery;
      expect(query.filter, BeanFilter.gifts);
      expect(c.state.filter, BeanFilter.gifts);
      expect(c.state.summary, summary);
      expect(c.state.list.items.map((i) => i.id), ['g1', 'g2']);
      // Choosing the same filter again does nothing.
      clearInteractions(history);
      await c.setFilter(BeanFilter.gifts);
      verifyNever(() => history(any()));
      await c.close();
    },
  );

  test(
    'loadMore appends the next page with the cursor and the filter',
    () async {
      when(() => history(any())).thenAnswer(
        (_) async => Success(Page(items: [line('a')], nextCursor: 'n1')),
      );
      final c = build();
      await c.load();
      when(
        () => history(any()),
      ).thenAnswer((_) async => Success(Page(items: [line('b')])));
      await c.loadMore();
      final query =
          verify(() => history(captureAny())).captured.last as BeanHistoryQuery;
      expect(query.page.cursor, 'n1');
      expect(c.state.list.items.map((i) => i.id), ['a', 'b']);
      expect(c.state.list.hasMore, isFalse);
      // Nothing more to load: no further request.
      clearInteractions(history);
      await c.loadMore();
      verifyNever(() => history(any()));
      await c.close();
    },
  );

  test('a failed loadMore keeps the lines and offers a retry', () async {
    when(() => history(any())).thenAnswer(
      (_) async => Success(Page(items: [line('a')], nextCursor: 'n1')),
    );
    final c = build();
    await c.load();
    when(
      () => history(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await c.loadMore();
    expect(c.state.list.items.length, 1);
    expect(c.state.list.status, PagedStatus.loaded);
    expect(c.state.list.loadMoreFailure, isNotNull);
    expect(c.state.list.hasMore, isTrue);
    await c.close();
  });
}
