import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  setUpAll(registerHostFallbacks);

  group('H14 earnings and H15 explainer', () {
    late MockGetEarnings getEarnings;
    setUp(() => getEarnings = MockGetEarnings());

    Widget page() => BlocProvider(
      create: (_) => HostEarningsCubit(getEarnings)..load(),
      child: const HostEarningsPage(),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('earnings render at $name', (tester) async {
        when(
          () => getEarnings(any()),
        ).thenAnswer((_) async => Success(sampleEarnings));
        await pumpHostPage(tester, page(), size: size);
        expect(find.textContaining(amount('2,10,750')), findsOneWidget);
        expect(find.text('Withdraw ₹621.50'), findsOneWidget);
        expect(find.text('ON HOLD · 7 DAYS'), findsOneWidget);
        expect(find.text('₹432.25'), findsOneWidget);
      });
    }

    testWidgets('withdraw opens the withdraw route', (tester) async {
      when(
        () => getEarnings(any()),
      ).thenAnswer((_) async => Success(sampleEarnings));
      await pumpHostPage(tester, page(), textScale: 1.3);
      await tester.ensureVisible(find.text('Withdraw ₹621.50'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw ₹621.50'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/withdraw'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('error at $size', (tester) async {
        when(
          () => getEarnings(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });

      testWidgets('explainer calculator at $size', (tester) async {
        await pumpHostPage(tester, const BeansExplainerPage(), size: size);
        expect(find.text('≈ ₹500'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '124300');
        await tester.pump();
        expect(find.text('≈ ₹621.50'), findsOneWidget);
      });
    }
  });

  group('H16–H18, H21, H25 withdraw', () {
    late MockGetEarnings getEarnings;
    late MockRequestWithdrawal request;
    setUp(() {
      getEarnings = MockGetEarnings();
      request = MockRequestWithdrawal();
      when(
        () => getEarnings(any()),
      ).thenAnswer((_) async => Success(sampleEarnings));
    });

    Widget page() => BlocProvider(
      create: (_) => HostWithdrawCubit(getEarnings, request)..load(),
      child: const HostWithdrawPage(),
    );

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.text('Withdraw ₹621.50'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm withdrawal'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm withdrawal'));
      await tester.pumpAndSettle();
    }

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('form renders at $name', (tester) async {
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('≈ ₹621.50'), findsOneWidget);
        expect(find.text('Max'), findsOneWidget);
      });
    }

    testWidgets('confirm → requested (H18)', (tester) async {
      when(
        () => request(any()),
      ).thenAnswer((_) async => Success(sampleWithdrawal));
      await pumpHostPage(tester, page(), textScale: 1.3);
      await confirm(tester);
      expect(find.text('Withdrawal requested'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('503 payouts_not_enabled shows H21 at $size', (tester) async {
        when(() => request(any())).thenAnswer(
          (_) async => const Err(ServerFailure(code: 'payouts_not_enabled')),
        );
        await pumpHostPage(tester, page(), size: size);
        await confirm(tester);
        expect(find.text('Withdrawals are coming soon'), findsOneWidget);
      });

      testWidgets('below minimum shows H25 at $size', (tester) async {
        when(
          () => getEarnings(any()),
        ).thenAnswer((_) async => const Success(lowEarnings));
        await pumpHostPage(tester, page(), size: size);
        expect(
          find.textContaining('Minimum withdrawal is ₹500'),
          findsOneWidget,
        );
        expect(find.text('86%'), findsOneWidget);
        final button = find.widgetWithText(FilledButton, 'Withdraw');
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
      });

      testWidgets('error at $size', (tester) async {
        when(
          () => getEarnings(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });
    }

    testWidgets('amount below minimum disables the button', (tester) async {
      await pumpHostPage(tester, page());
      await tester.enterText(find.byType(TextField), '5000');
      await tester.pump();
      expect(
        find.text('The minimum is 1,00,000 Beans (₹500).'),
        findsOneWidget,
      );
    });

    testWidgets('insufficient beans reports and refreshes', (tester) async {
      when(() => request(any())).thenAnswer(
        (_) async => const Err(
          BusinessRuleFailure(code: 'insufficient_available_beans'),
        ),
      );
      await pumpHostPage(tester, page());
      await confirm(tester);
      expect(find.textContaining("don't have that many"), findsOneWidget);
    });
  });

  group('H19 payout history and H20 payout method', () {
    late MockListWithdrawals list;
    setUp(() => list = MockListWithdrawals());

    Widget page() => BlocProvider(
      create: (_) => HostPayoutsCubit(list)..load(),
      child: const HostPayoutHistoryPage(),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('history renders at $name', (tester) async {
        when(() => list(any())).thenAnswer(
          (_) async => Success(
            Page(
              items: [
                sampleWithdrawal,
                Withdrawal(
                  id: 'w2',
                  beans: 200000,
                  amountPaise: 100000,
                  status: WithdrawalStatuses.failed,
                  requestedAt: DateTime.utc(2026, 10, 26),
                  paidAt: null,
                ),
              ],
            ),
          ),
        );
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Requested'), findsOneWidget);
        expect(find.text('Failed · returned'), findsOneWidget);
      });

      testWidgets('payout method page at $name has no form', (tester) async {
        await pumpHostPage(tester, const HostPayoutMethodPage(), size: size);
        expect(find.text('Available after payouts launch'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      });
    }

    for (final size in [phone, tablet]) {
      testWidgets('empty and error at $size', (tester) async {
        when(
          () => list(any()),
        ).thenAnswer((_) async => const Success(Page<Withdrawal>(items: [])));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('No withdrawals yet'), findsOneWidget);
        when(
          () => list(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });
    }
  });
}

/// A CurrencyAmount's text: the amount, after its inline glyph (UI/UX pass:
/// the glyph is now an inline span so the amount can wrap).
RegExp amount(String text) => RegExp('^\uFFFC?${RegExp.escape(text)}\$');
