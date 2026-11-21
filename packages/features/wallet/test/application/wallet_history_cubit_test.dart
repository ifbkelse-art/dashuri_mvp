import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Entries extends Mock implements ListWalletEntries {}

class _Find extends Mock implements FindWalletEntry {}

WalletEntry e(String id) => WalletEntry(
  id: id,
  currency: 'DIAMOND',
  kind: 'call_settlement',
  amount: -100,
  createdAt: DateTime.utc(2026, 11, 19),
  reference: null,
);

void main() {
  late _Entries list;
  setUpAll(() => registerFallbackValue(const PageRequest()));
  setUp(() => list = _Entries());

  blocTest<WalletHistoryCubit, WalletHistoryState>(
    'loads the first page and appends the next one with the cursor',
    setUp: () {
      when(() => list(const PageRequest(limit: 30))).thenAnswer(
        (_) async => Success(Page(items: [e('1')], nextCursor: 'c1')),
      );
      when(
        () => list(const PageRequest(cursor: 'c1', limit: 30)),
      ).thenAnswer((_) async => Success(Page(items: [e('2')])));
    },
    build: () => WalletHistoryCubit(list),
    act: (c) async {
      await c.load();
      await c.loadMore();
      await c.loadMore(); // no more pages: ignored
    },
    expect: () => [
      const WalletHistoryState(status: WalletHistoryStatus.loading),
      WalletHistoryState(
        status: WalletHistoryStatus.loaded,
        entries: [e('1')],
        nextCursor: 'c1',
      ),
      WalletHistoryState(
        status: WalletHistoryStatus.loaded,
        entries: [e('1')],
        nextCursor: 'c1',
        loadingMore: true,
      ),
      WalletHistoryState(
        status: WalletHistoryStatus.loaded,
        entries: [e('1'), e('2')],
      ),
    ],
  );

  blocTest<WalletHistoryCubit, WalletHistoryState>(
    'a failed next page keeps entries and exposes an inline retry',
    setUp: () {
      when(() => list(const PageRequest(limit: 30))).thenAnswer(
        (_) async => Success(Page(items: [e('1')], nextCursor: 'c1')),
      );
      when(
        () => list(const PageRequest(cursor: 'c1', limit: 30)),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: () => WalletHistoryCubit(list),
    act: (c) async {
      await c.load();
      await c.loadMore();
    },
    verify: (c) {
      expect(c.state.entries, [e('1')]);
      expect(c.state.moreFailure, const NetworkFailure());
      expect(c.state.nextCursor, 'c1');
    },
  );

  group('TransactionDetailCubit', () {
    late _Find find;
    setUp(() => find = _Find());

    test('uses the entry passed by the list without fetching', () async {
      final c = TransactionDetailCubit(find, entryId: '1', entry: e('1'));
      await c.load();
      expect(c.state, TransactionDetailLoaded(e('1')));
      verifyNever(() => find(any()));
      await c.close();
    });

    blocTest<TransactionDetailCubit, TransactionDetailState>(
      'falls back to fetching by id',
      setUp: () =>
          when(() => find('1')).thenAnswer((_) async => Success(e('1'))),
      build: () => TransactionDetailCubit(find, entryId: '1'),
      act: (c) => c.load(),
      expect: () => [
        const TransactionDetailLoading(),
        TransactionDetailLoaded(e('1')),
      ],
    );

    blocTest<TransactionDetailCubit, TransactionDetailState>(
      'fails when the entry is not found',
      setUp: () => when(
        () => find('1'),
      ).thenAnswer((_) async => const Err(NotFoundFailure())),
      build: () => TransactionDetailCubit(find, entryId: '1'),
      act: (c) => c.load(),
      expect: () => [
        const TransactionDetailLoading(),
        const TransactionDetailFailed(NotFoundFailure()),
      ],
    );
  });
}
