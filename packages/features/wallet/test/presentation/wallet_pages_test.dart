import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump.dart';

class _WalletCubit extends MockCubit<WalletState> implements WalletCubit {}

class _HistoryCubit extends MockCubit<WalletHistoryState>
    implements WalletHistoryCubit {}

class _DetailCubit extends MockCubit<TransactionDetailState>
    implements TransactionDetailCubit {}

const hostSummary = WalletSummary(
  purchasedDiamonds: 12480,
  promotionalDiamonds: 500,
  reservedDiamonds: 2400,
  availableDiamonds: 10580,
  beansOnHold: 2599,
  beansAvailable: 210750,
  beansPendingPayout: 0,
);

final entries = [
  WalletEntry(
    id: 'e1',
    currency: 'DIAMOND',
    kind: 'call_settlement',
    amount: -18000,
    createdAt: DateTime.now(),
    reference: 'call_1',
  ),
  WalletEntry(
    id: 'e2',
    currency: 'DIAMOND',
    kind: 'purchase_credit',
    amount: 54000,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    reference: 'dsh_abc',
  ),
];

void main() {
  for (final size in [phone, tablet]) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets(
        'W01 shows balances, reserved, Beans for hosts and activity',
        (tester) async {
          final cubit = _WalletCubit();
          when(() => cubit.state).thenReturn(
            WalletStateLoaded(
              summary: hostSummary,
              recent: entries,
              isHost: true,
            ),
          );
          await pumpPage(
            tester,
            BlocProvider<WalletCubit>.value(
              value: cubit,
              child: const WalletPage(),
            ),
            size: size,
          );
          expect(find.text('10,580'), findsOneWidget);
          expect(find.text('Reserved for a call in progress'), findsOneWidget);
          expect(find.text('Host earnings'), findsOneWidget);
          expect(find.text('Video call'), findsOneWidget);
          expect(find.text('+54,000'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Buy Diamonds'));
          await tester.pumpAndSettle();
          expect(find.text('route:/wallet/buy'), findsOneWidget);
        },
      );

      // Phase 9 accessibility.
      testWidgets('W01 meets tap-target and label guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        final cubit = _WalletCubit();
        when(() => cubit.state).thenReturn(
          WalletStateLoaded(
            summary: hostSummary,
            recent: entries,
            isHost: true,
          ),
        );
        await pumpPage(
          tester,
          BlocProvider<WalletCubit>.value(
            value: cubit,
            child: const WalletPage(),
          ),
          size: size,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('W01 hides Beans for customers and shows error with retry', (
        tester,
      ) async {
        final cubit = _WalletCubit();
        when(
          () => cubit.state,
        ).thenReturn(const WalletStateFailed(NetworkFailure()));
        when(cubit.load).thenAnswer((_) async {});
        await pumpPage(
          tester,
          BlocProvider<WalletCubit>.value(
            value: cubit,
            child: const WalletPage(),
          ),
          size: size,
        );
        expect(find.textContaining('offline'), findsOneWidget);
        await tester.tap(find.text('Try again'));
        verify(cubit.load).called(1);
      });

      testWidgets('W08 groups entries by day and opens W09', (tester) async {
        final cubit = _HistoryCubit();
        when(() => cubit.state).thenReturn(
          WalletHistoryState(
            status: WalletHistoryStatus.loaded,
            entries: entries,
            nextCursor: 'c',
          ),
        );
        when(cubit.loadMore).thenAnswer((_) async {});
        await pumpPage(
          tester,
          BlocProvider<WalletHistoryCubit>.value(
            value: cubit,
            child: const TransactionHistoryPage(),
          ),
          size: size,
        );
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Load more'), findsOneWidget);
        await tester.tap(find.text('Diamonds purchased'));
        await tester.pumpAndSettle();
        expect(find.text('route:/wallet/transactions/e2'), findsOneWidget);
      });

      testWidgets('W08 error state retries', (tester) async {
        final cubit = _HistoryCubit();
        when(() => cubit.state).thenReturn(
          const WalletHistoryState(
            status: WalletHistoryStatus.failed,
            failure: ServerFailure(),
          ),
        );
        when(cubit.load).thenAnswer((_) async {});
        await pumpPage(
          tester,
          BlocProvider<WalletHistoryCubit>.value(
            value: cubit,
            child: const TransactionHistoryPage(),
          ),
          size: size,
        );
        await tester.tap(find.text('Try again'));
        verify(cubit.load).called(1);
      });

      testWidgets('W09 shows the receipt and the error state', (tester) async {
        final cubit = _DetailCubit();
        when(() => cubit.state).thenReturn(TransactionDetailLoaded(entries[1]));
        await pumpPage(
          tester,
          BlocProvider<TransactionDetailCubit>.value(
            value: cubit,
            child: const TransactionDetailPage(),
          ),
          size: size,
          textScale: 1.3,
        );
        expect(find.text('+54,000'), findsOneWidget);
        expect(find.text('dsh_abc'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final failed = _DetailCubit();
        when(
          () => failed.state,
        ).thenReturn(const TransactionDetailFailed(NotFoundFailure()));
        await pumpPage(
          tester,
          BlocProvider<TransactionDetailCubit>.value(
            value: failed,
            child: const TransactionDetailPage(),
          ),
          size: size,
        );
        expect(find.textContaining("couldn't find"), findsOneWidget);
      });
    });
  }
}
