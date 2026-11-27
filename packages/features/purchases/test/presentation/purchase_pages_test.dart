import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_purchases/feature_purchases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

class _Bloc extends MockBloc<PurchaseEvent, PurchaseState>
    implements PurchaseBloc {}

class _ResultCubit extends MockCubit<PaymentResultState>
    implements PaymentResultCubit {}

const ready = PurchaseState(
  status: PurchaseStatus.ready,
  packages: [starter, popular],
  rails: bothRails,
  serverRails: bothRails,
  currentBalance: 12480,
  selectedProductId: 'dia_1199',
);

Widget withBloc(PurchaseBloc b, Widget child) =>
    BlocProvider<PurchaseBloc>.value(value: b, child: child);

void main() {
  setUpAll(() => registerFallbackValue(const PurchasePackagesRequested()));

  test('W02 grid columns: 2 on phones, 3–4 on tablets', () {
    expect(BuyDiamondsPage.columnsFor(360), 2);
    expect(BuyDiamondsPage.columnsFor(700), 3);
    expect(BuyDiamondsPage.columnsFor(1024), 4);
  });

  for (final size in [phone, tablet]) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      // Phase 9 accessibility.
      testWidgets('W02 meets tap-target and label guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        final b = _Bloc();
        when(() => b.state).thenReturn(ready);
        await pumpPage(
          tester,
          withBloc(
            b,
            const BuyDiamondsPage(ratePerMinute: 2400, hostName: 'Ananya'),
          ),
          size: size,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('W02 packages, hint, provisional note and Continue', (
        tester,
      ) async {
        final b = _Bloc();
        when(() => b.state).thenReturn(ready);
        await pumpPage(
          tester,
          withBloc(
            b,
            const BuyDiamondsPage(ratePerMinute: 2400, hostName: 'Ananya'),
          ),
          size: size,
          textScale: 1.3,
        );
        expect(find.textContaining(amount('54,000')), findsOneWidget);
        expect(find.text('MOST POPULAR'), findsOneWidget);
        expect(find.text('≈ 22 min with Ananya'), findsOneWidget);
        expect(find.textContaining('provisional'), findsOneWidget);
        expect(find.textContaining(amount('12,480')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('STARTER'));
        verify(
          () => b.add(const PurchasePackageHighlighted('dia_99')),
        ).called(1);
        await tester.tap(find.text('Continue · ₹1,199'));
        await tester.pumpAndSettle();
        expect(find.text('route:/wallet/checkout/dia_1199'), findsOneWidget);
      });

      testWidgets('W02 error with retry', (tester) async {
        final b = _Bloc();
        when(() => b.state).thenReturn(
          const PurchaseState(
            status: PurchaseStatus.failed,
            failure: NetworkFailure(),
          ),
        );
        await pumpPage(
          tester,
          withBloc(b, const BuyDiamondsPage()),
          size: size,
        );
        await tester.tap(find.text('Try again'));
        verify(() => b.add(const PurchasePackagesRequested())).called(1);
      });

      testWidgets('W03 summary; rail sheet when both rails are on', (
        tester,
      ) async {
        final b = _Bloc();
        when(() => b.state).thenReturn(ready);
        await pumpPage(
          tester,
          withBloc(b, const CheckoutPage(productId: 'dia_1199')),
          size: size,
        );
        expect(find.text('Includes GST'), findsOneWidget);
        expect(find.text('Pay ₹1,199'), findsOneWidget);
        await tester.tap(find.text('Pay ₹1,199'));
        await tester.pumpAndSettle();
        expect(find.text('How would you like to pay?'), findsOneWidget);
        await tester.tap(find.text('UPI, cards & net banking').last);
        await tester.pumpAndSettle();
        verify(
          () => b.add(const PurchaseCashfreeRequested('dia_1199')),
        ).called(1);
      });

      testWidgets('W03 single rail pays directly with Play', (tester) async {
        final b = _Bloc();
        when(() => b.state).thenReturn(
          const PurchaseState(
            status: PurchaseStatus.ready,
            packages: [popular],
            rails: {PaymentRail.googlePlay},
            serverRails: bothRails,
          ),
        );
        await pumpPage(
          tester,
          withBloc(b, const CheckoutPage(productId: 'dia_1199')),
          size: size,
        );
        await tester.tap(find.text('Pay ₹1,199'));
        await tester.pump();
        verify(
          () => b.add(const PurchasePackageSelected('dia_1199')),
        ).called(1);
      });

      testWidgets('W03 verification failure offers a retry; W04 processing', (
        tester,
      ) async {
        final b = _Bloc();
        when(() => b.state).thenReturn(
          ready.copyWith(
            status: PurchaseStatus.failed,
            failure: const NetworkFailure(),
            canRetryVerification: true,
          ),
        );
        await pumpPage(
          tester,
          withBloc(b, const CheckoutPage(productId: 'dia_1199')),
          size: size,
        );
        await tester.ensureVisible(find.text('Retry confirmation'));
        await tester.pump();
        await tester.tap(find.text('Retry confirmation'));
        verify(() => b.add(const PurchaseVerificationRetried())).called(1);

        final p = _Bloc();
        when(() => p.state).thenReturn(
          ready.copyWith(
            status: PurchaseStatus.confirming,
            cashfreeOrder: order(),
          ),
        );
        await pumpPage(
          tester,
          withBloc(p, const CheckoutPage(productId: 'dia_1199')),
          size: size,
        );
        expect(find.text('Waiting for confirmation'), findsOneWidget);
        expect(find.textContaining('Order dsh_1'), findsOneWidget);
      });

      testWidgets('W03 navigates to the result when the flow completes', (
        tester,
      ) async {
        final b = _Bloc();
        const result = PaymentResult(
          rail: PaymentRail.cashfree,
          outcome: PaymentOutcome.success,
          orderId: 'dsh_1',
          productId: 'dia_1199',
          diamondsCredited: 54000,
        );
        whenListen(
          b,
          Stream.fromIterable([
            ready.copyWith(status: PurchaseStatus.completed, result: result),
          ]),
          initialState: ready,
        );
        await pumpPage(
          tester,
          withBloc(b, const CheckoutPage(productId: 'dia_1199')),
          size: size,
        );
        await tester.pumpAndSettle();
        expect(find.text('route:/wallet/payment/dsh_1'), findsOneWidget);
      });

      Future<void> pumpResult(WidgetTester tester, PaymentResultState s) async {
        final c = _ResultCubit();
        when(() => c.state).thenReturn(s);
        when(c.load).thenAnswer((_) async {});
        when(c.recheck).thenAnswer((_) async {});
        await pumpPage(
          tester,
          BlocProvider<PaymentResultCubit>.value(
            value: c,
            child: const PaymentResultPage(),
          ),
          size: size,
        );
      }

      testWidgets('W05 success shows server-credited Diamonds', (tester) async {
        await pumpResult(
          tester,
          const PaymentResultLoaded(
            PaymentResult(
              rail: PaymentRail.googlePlay,
              outcome: PaymentOutcome.success,
              orderId: 'p1',
              productId: 'dia_1199',
              diamondsCredited: 54000,
              amountPaise: 119900,
            ),
          ),
        );
        expect(find.text('+54,000'), findsOneWidget);
        expect(find.text('Start a call'), findsOneWidget);
        await tester.ensureVisible(find.text('Back to wallet'));
        await tester.pump();
        await tester.tap(find.text('Back to wallet'));
        await tester.pumpAndSettle();
        expect(find.text('route:/wallet'), findsOneWidget);
      });

      testWidgets('W06 failure: reason, try again, other method, support', (
        tester,
      ) async {
        await pumpResult(
          tester,
          const PaymentResultLoaded(
            PaymentResult(
              rail: PaymentRail.cashfree,
              outcome: PaymentOutcome.failed,
              orderId: 'dsh_1',
              productId: 'dia_1199',
              amountPaise: 119900,
              failureCode: 'payment_expired',
            ),
          ),
        );
        expect(find.textContaining('expired'), findsOneWidget);
        expect(find.text('Use another method'), findsOneWidget);
        expect(find.textContaining('Reference dsh_1'), findsOneWidget);
        await tester.ensureVisible(find.text('Try again · ₹1,199'));
        await tester.pump();
        await tester.tap(find.text('Try again · ₹1,199'));
        await tester.pumpAndSettle();
        expect(
          find.text('route:/wallet/checkout/dia_1199?rail=cashfree'),
          findsOneWidget,
        );
      });

      testWidgets('W07 pending with check again; load error', (tester) async {
        await pumpResult(
          tester,
          const PaymentResultLoaded(
            PaymentResult(
              rail: PaymentRail.cashfree,
              outcome: PaymentOutcome.pending,
              orderId: 'dsh_1',
              productId: 'dia_1199',
              diamonds: 54000,
              amountPaise: 119900,
            ),
          ),
        );
        expect(find.text('Confirming your payment'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('Check again'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await pumpResult(tester, const PaymentResultFailed(NotFoundFailure()));
        expect(find.text("We couldn't load this payment"), findsOneWidget);
      });
    });
  }
}

/// A CurrencyAmount's text: the amount, after its inline glyph (UI/UX pass:
/// the glyph is now an inline span so the amount can wrap).
RegExp amount(String text) => RegExp('^\uFFFC?${RegExp.escape(text)}\$');
