import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

final _now = DateTime.utc(2026, 11, 28, 14);

BeanHistoryItem _item(
  String id,
  BeanLineType type,
  String title, {
  required int beans,
  required int balance,
  DateTime? at,
  String? subtitle,
  int? moved,
  bool? onHold,
  DateTime? releasesAt,
  DateTime? releasedAt,
}) => BeanHistoryItem(
  id: id,
  occurredAt: at ?? DateTime.utc(2026, 11, 28, 12),
  type: type,
  title: title,
  subtitle: subtitle,
  beans: beans,
  movedBeans: moved,
  balanceAfter: balance,
  onHold: onHold,
  releasesAt: releasesAt,
  releasedAt: releasedAt,
);

final _items = [
  _item(
    'g',
    BeanLineType.gift,
    '🌹 Rose from Bruce',
    beans: 899,
    balance: 5957,
    subtitle: 'Gift during a video call',
    onHold: true,
    releasesAt: DateTime.utc(2026, 12, 5, 12),
  ),
  _item(
    'c',
    BeanLineType.call,
    'Call with Bruce',
    beans: 319,
    balance: 5058,
    subtitle: '1 min 04 s · 500 Diamonds/min',
    onHold: true,
    releasesAt: DateTime.utc(2026, 12, 5, 11),
  ),
  _item(
    'r',
    BeanLineType.release,
    'Released from hold',
    beans: 0,
    moved: 599,
    balance: 4739,
    at: DateTime.utc(2026, 11, 27, 12),
    subtitle: 'Call with Bruce is now withdrawable',
  ),
  _item(
    'x',
    BeanLineType.reversal,
    'Earnings reversed',
    beans: -100,
    balance: 4739,
    at: DateTime.utc(2026, 11, 20, 12),
  ),
  _item(
    'o',
    BeanLineType.call,
    'Call with Meera',
    beans: 599,
    balance: 4839,
    at: DateTime.utc(2026, 11, 19, 12),
    onHold: false,
    releasedAt: DateTime.utc(2026, 11, 26, 12),
  ),
];

const _summary = BeanSummary(
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
    when(() => sum(any())).thenAnswer((_) async => const Success(_summary));
    when(
      () => history(any()),
    ).thenAnswer((_) async => Success(Page(items: _items)));
  });

  Widget page() => BlocProvider(
    create: (_) => HostBeansHistoryCubit(history, sum)..load(),
    child: HostBeansHistoryPage(now: () => _now),
  );

  for (final MapEntry(key: name, value: size) in testSizes.entries) {
    testWidgets('history renders at $name', (tester) async {
      await pumpHostPage(tester, page(), size: size);
      expect(find.text('Beans history'), findsOneWidget);
      expect(find.text('BEANS BALANCE'), findsOneWidget);
      expect(find.text('ON HOLD'), findsOneWidget);
      expect(find.text('Call with Bruce'), findsWidgets);
    });
  }

  testWidgets('lines show signs, moves, balance and hold status', (
    tester,
  ) async {
    await pumpHostPage(tester, page(), size: const Size(390, 1800));
    // Earnings are positive, reversals negative, releases are moves.
    expect(find.text('+899'), findsOneWidget);
    expect(find.text('+319'), findsOneWidget);
    expect(find.text('−100'), findsOneWidget);
    expect(find.text('599'), findsWidgets); // the move and the old call
    // Running balance on every line.
    expect(find.text('Balance 5,957'), findsOneWidget);
    expect(find.text('Balance 5,058'), findsOneWidget);
    // Wording from the server is shown as is.
    expect(find.text('🌹 Rose from Bruce'), findsOneWidget);
    expect(find.text('1 min 04 s · 500 Diamonds/min'), findsOneWidget);
    expect(find.text('Call with Bruce is now withdrawable'), findsOneWidget);
    // Hold status for earnings only.
    expect(find.textContaining('On hold · withdrawable'), findsNWidgets(2));
    expect(find.text('Released Thu, 26 Nov'), findsOneWidget);
    // Lines are grouped under day headings.
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
  });

  testWidgets('the header adds up: balance, split, earned and lifetime', (
    tester,
  ) async {
    await pumpHostPage(tester, page(), size: const Size(390, 1800));
    expect(find.text('AVAILABLE'), findsOneWidget);
    expect(find.text('IN PAYOUT'), findsOneWidget);
    expect(find.text('Lifetime 6,497 Beans'), findsOneWidget);
    expect(
      find.text('Calls 599 · Gifts 3,898 · Free calls 2,000'),
      findsOneWidget,
    );
    expect(find.text('Paid out 400 · Reversed 100'), findsOneWidget);
  });

  testWidgets('choosing a filter asks for it and shows its empty state', (
    tester,
  ) async {
    await pumpHostPage(tester, page(), size: const Size(390, 1800));
    when(
      () => history(any()),
    ).thenAnswer((_) async => const Success(Page<BeanHistoryItem>(items: [])));
    await tester.tap(find.text('Gifts'));
    await tester.pumpAndSettle();
    final query =
        verify(() => history(captureAny())).captured.last as BeanHistoryQuery;
    expect(query.filter, BeanFilter.gifts);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Try another filter.'), findsOneWidget);
    // The header is still there.
    expect(find.text('BEANS BALANCE'), findsOneWidget);
  });

  testWidgets('no Beans at all says how to earn them', (tester) async {
    when(
      () => history(any()),
    ).thenAnswer((_) async => const Success(Page<BeanHistoryItem>(items: [])));
    await pumpHostPage(tester, page(), size: const Size(390, 1800));
    expect(find.text('No Beans yet'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    when(() => sum(any())).thenAnswer((_) async => const Err(NetworkFailure()));
    when(
      () => history(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pumpHostPage(tester, page());
    expect(find.text("Couldn't load your Beans history"), findsOneWidget);
    when(() => sum(any())).thenAnswer((_) async => const Success(_summary));
    when(
      () => history(any()),
    ).thenAnswer((_) async => Success(Page(items: _items)));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('BEANS BALANCE'), findsOneWidget);
  });

  testWidgets('large text keeps every line readable', (tester) async {
    await pumpHostPage(
      tester,
      page(),
      size: const Size(360, 1800),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('+899'), findsOneWidget);
  });

  testWidgets('Earnings links to the history', (tester) async {
    final getEarnings = MockGetEarnings();
    when(
      () => getEarnings(any()),
    ).thenAnswer((_) async => Success(sampleEarnings));
    await pumpHostPage(
      tester,
      BlocProvider(
        create: (_) => HostEarningsCubit(getEarnings)..load(),
        child: const HostEarningsPage(),
      ),
      size: const Size(390, 1400),
    );
    expect(find.text('Beans history'), findsOneWidget);
  });
}
