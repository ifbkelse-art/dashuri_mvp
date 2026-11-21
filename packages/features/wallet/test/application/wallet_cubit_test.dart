import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Summary extends Mock implements GetWalletSummary {}

class _Entries extends Mock implements ListWalletEntries {}

class _IsHost extends Mock implements GetIsHost {}

class _Watch extends Mock implements WatchWalletUpdates {}

const summary = WalletSummary(
  purchasedDiamonds: 12480,
  promotionalDiamonds: 0,
  reservedDiamonds: 0,
  availableDiamonds: 12480,
  beansOnHold: 0,
  beansAvailable: 0,
  beansPendingPayout: 0,
);
const summary2 = WalletSummary(
  purchasedDiamonds: 66480,
  promotionalDiamonds: 0,
  reservedDiamonds: 0,
  availableDiamonds: 66480,
  beansOnHold: 0,
  beansAvailable: 0,
  beansPendingPayout: 0,
);
final entry = WalletEntry(
  id: 'e1',
  currency: 'DIAMOND',
  kind: 'purchase_credit',
  amount: 54000,
  createdAt: DateTime.utc(2026, 11, 19),
  reference: 'dsh_1',
);

void main() {
  late _Summary getSummary;
  late _Entries entries;
  late _IsHost isHost;
  late _Watch watch;
  late StreamController<void> updates;

  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue(const PageRequest());
  });
  setUp(() {
    getSummary = _Summary();
    entries = _Entries();
    isHost = _IsHost();
    watch = _Watch();
    updates = StreamController<void>.broadcast();
    when(() => watch(any())).thenAnswer((_) => updates.stream);
    when(
      () => entries(any()),
    ).thenAnswer((_) async => Success(Page(items: [entry])));
    when(() => isHost(any())).thenAnswer((_) async => const Success(false));
  });
  tearDown(() => updates.close());

  WalletCubit build() => WalletCubit(getSummary, entries, isHost, watch);

  blocTest<WalletCubit, WalletState>(
    'emits Loading then Failed when the summary fails',
    setUp: () => when(
      () => getSummary(any()),
    ).thenAnswer((_) async => const Err<WalletSummary>(NetworkFailure())),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const <WalletState>[
      WalletStateLoading(),
      WalletStateFailed(NetworkFailure()),
    ],
  );

  blocTest<WalletCubit, WalletState>(
    'loads balances, recent activity and the host flag',
    setUp: () => when(
      () => getSummary(any()),
    ).thenAnswer((_) async => const Success(summary)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const WalletStateLoading(),
      WalletStateLoaded(summary: summary, recent: [entry]),
    ],
    verify: (_) => verify(
      () => entries(const PageRequest(limit: WalletCubit.recentCount)),
    ).called(1),
  );

  blocTest<WalletCubit, WalletState>(
    'falls back to "has Beans" when the host flag cannot load',
    setUp: () {
      when(() => getSummary(any())).thenAnswer(
        (_) async => const Success(
          WalletSummary(
            purchasedDiamonds: 0,
            promotionalDiamonds: 0,
            reservedDiamonds: 0,
            availableDiamonds: 0,
            beansOnHold: 10,
            beansAvailable: 0,
            beansPendingPayout: 0,
          ),
        ),
      );
      when(
        () => isHost(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    verify: (c) => expect((c.state as WalletStateLoaded).isHost, isTrue),
  );

  test('a wallet.updated hint refreshes the balance silently', () async {
    var calls = 0;
    when(
      () => getSummary(any()),
    ).thenAnswer((_) async => Success(calls++ == 0 ? summary : summary2));
    final cubit = build();
    await cubit.load();
    final states = <WalletState>[];
    final sub = cubit.stream.listen(states.add);
    updates.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(states.first, isA<WalletStateLoaded>());
    expect((states.first as WalletStateLoaded).refreshing, isTrue);
    expect((cubit.state as WalletStateLoaded).summary, summary2);
    expect((cubit.state as WalletStateLoaded).refreshing, isFalse);
    await sub.cancel();
    await cubit.close();
  });

  test('a failed refresh keeps the shown balance', () async {
    var calls = 0;
    when(() => getSummary(any())).thenAnswer(
      (_) async => calls++ == 0
          ? const Success(summary)
          : const Err<WalletSummary>(NetworkFailure()),
    );
    final cubit = build();
    await cubit.load();
    await cubit.refresh();
    expect((cubit.state as WalletStateLoaded).summary, summary);
    await cubit.close();
  });
}
