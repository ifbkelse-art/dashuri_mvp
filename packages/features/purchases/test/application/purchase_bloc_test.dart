import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_purchases/feature_purchases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';

class _Load extends Mock implements LoadDiamondPackages {}

class _Start extends Mock implements StartPurchase {}

class _Watch extends Mock implements WatchPurchaseUpdates {}

class _Verify extends Mock implements VerifyPurchase {}

class _Rails extends Mock implements GetClientRails {}

class _Create extends Mock implements CreateCashfreeOrder {}

class _Get extends Mock implements GetCashfreeOrder {}

class _Open extends Mock implements OpenCashfreeCheckout {}

typedef VerifyInput = ({
  PurchaseNeedsVerification purchase,
  IdempotencyKey key,
});
typedef CreateInput = ({String productId, IdempotencyKey key});

void main() {
  late _Load load;
  late _Start start;
  late _Watch watch;
  late _Verify verifyUc;
  late _Rails rails;
  late _Create create;
  late _Get get;
  late _Open open;
  late StreamController<PurchaseUpdate> store;
  late List<Duration> sleeps;
  const purchase = PurchaseNeedsVerification(
    'dia_1199',
    purchaseToken: 'tok-1',
    orderId: 'GPA.1',
  );

  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue((purchase: purchase, key: IdempotencyKey.generate()));
    registerFallbackValue((productId: 'x', key: IdempotencyKey.generate()));
    registerFallbackValue(order());
  });

  setUp(() {
    load = _Load();
    start = _Start();
    watch = _Watch();
    verifyUc = _Verify();
    rails = _Rails();
    create = _Create();
    get = _Get();
    open = _Open();
    sleeps = [];
    store = StreamController<PurchaseUpdate>.broadcast();
    when(() => watch(any())).thenAnswer((_) => store.stream);
    when(() => load(any())).thenAnswer((_) async => Success(catalogue()));
    when(() => rails(any())).thenAnswer((_) async => const Success(bothRails));
    when(() => start(any())).thenAnswer((_) async => const Success(null));
  });
  tearDown(() => store.close());

  PurchaseBloc build() => PurchaseBloc(
    load,
    start,
    watch,
    verifyUc,
    clientRails: rails,
    createCashfreeOrder: create,
    getCashfreeOrder: get,
    openCashfreeCheckout: open,
    sleep: (d) async => sleeps.add(d),
  );

  Future<PurchaseBloc> loaded() async {
    final b = build()..add(const PurchasePackagesRequested());
    await b.stream.firstWhere((s) => s.status == PurchaseStatus.ready);
    return b;
  }

  group('catalogue', () {
    blocTest<PurchaseBloc, PurchaseState>(
      'loads packages and intersects server and device rails',
      setUp: () => when(
        () => rails(any()),
      ).thenAnswer((_) async => const Success({PaymentRail.googlePlay})),
      build: build,
      act: (b) => b.add(const PurchasePackagesRequested()),
      expect: () => [
        const PurchaseState(status: PurchaseStatus.loading),
        const PurchaseState(
          status: PurchaseStatus.ready,
          packages: [starter, popular],
          rails: {PaymentRail.googlePlay},
          serverRails: bothRails,
          currentBalance: 12480,
          selectedProductId: 'dia_1199', // the badged pack
        ),
      ],
    );

    blocTest<PurchaseBloc, PurchaseState>(
      'catalogue failure',
      setUp: () => when(
        () => load(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (b) => b.add(const PurchasePackagesRequested()),
      expect: () => [
        const PurchaseState(status: PurchaseStatus.loading),
        const PurchaseState(
          status: PurchaseStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  group('Google Play', () {
    test('credited: verified on the server, result from the server', () async {
      when(() => verifyUc(any())).thenAnswer(
        (_) async => const Success(
          PurchaseVerification(
            purchaseId: 'p1',
            status: 'credited',
            diamondsCredited: 54000,
          ),
        ),
      );
      final b = await loaded();
      b.add(const PurchasePackageSelected('dia_1199'));
      await b.stream.firstWhere((s) => s.status == PurchaseStatus.inStore);
      verify(() => start('dia_1199')).called(1);
      store.add(purchase);
      final done = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.completed,
      );
      expect(done.result!.outcome, PaymentOutcome.success);
      expect(done.result!.diamondsCredited, 54000);
      expect(done.result!.orderId, 'p1');
      expect(done.result!.amountPaise, 119900);
      await b.close();
    });

    test('Play pending payment → pending result (W07)', () async {
      final b = await loaded();
      store.add(const PurchasePending('dia_1199'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.pendingPayment,
      );
      expect(s.result!.outcome, PaymentOutcome.pending);
      expect(s.result!.diamonds, 54000);
      await b.close();
    });

    test('server pending → pending result', () async {
      when(() => verifyUc(any())).thenAnswer(
        (_) async => const Success(
          PurchaseVerification(
            purchaseId: 'p1',
            status: 'pending',
            diamondsCredited: 0,
          ),
        ),
      );
      final b = await loaded();
      store.add(purchase);
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.completed,
      );
      expect(s.result!.outcome, PaymentOutcome.pending);
      await b.close();
    });

    test('server rejected → failure with reason', () async {
      when(() => verifyUc(any())).thenAnswer(
        (_) async => const Success(
          PurchaseVerification(
            purchaseId: 'p1',
            status: 'rejected',
            diamondsCredited: 0,
          ),
        ),
      );
      final b = await loaded();
      store.add(purchase);
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.completed,
      );
      expect(s.result!.outcome, PaymentOutcome.failed);
      expect(s.result!.failureCode, 'purchase_rejected');
      expect(s.result!.diamondsCredited, 0);
      await b.close();
    });

    test('retrying the same token reuses the idempotency key', () async {
      final keys = <String>[];
      var calls = 0;
      when(() => verifyUc(any())).thenAnswer((inv) async {
        final input = inv.positionalArguments.first as VerifyInput;
        keys.add(input.key.value);
        return calls++ == 0
            ? const Err(NetworkFailure())
            : const Success(
                PurchaseVerification(
                  purchaseId: 'p1',
                  status: 'credited',
                  diamondsCredited: 54000,
                ),
              );
      });
      final b = await loaded();
      store.add(purchase);
      final failed = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.failed,
      );
      expect(failed.canRetryVerification, isTrue);
      b.add(const PurchaseVerificationRetried());
      await b.stream.firstWhere((s) => s.status == PurchaseStatus.completed);
      // Play redelivering the same token also reuses the key.
      store.add(purchase);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(keys, hasLength(3));
      expect(keys.toSet(), hasLength(1));
      await b.close();
    });

    test('store errors and cancellation', () async {
      final b = await loaded();
      store.add(const PurchaseStoreError('dia_1199', 'BillingResponse.error'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.failed,
      );
      expect(s.failure, const PlatformFailure(code: 'BillingResponse.error'));
      store.add(const PurchaseCancelled('dia_1199'));
      await b.stream.firstWhere((s) => s.status == PurchaseStatus.ready);
      await b.close();
    });

    test('Play unavailable on this device → billing_unavailable', () async {
      when(
        () => rails(any()),
      ).thenAnswer((_) async => const Success({PaymentRail.cashfree}));
      final b = await loaded();
      b.add(const PurchasePackageSelected('dia_1199'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.failed,
      );
      expect(s.failure!.code, 'billing_unavailable');
      verifyNever(() => start(any()));
      await b.close();
    });
  });

  group('Cashfree', () {
    test('success: always confirmed with the server', () async {
      when(() => create(any())).thenAnswer((_) async => Success(order()));
      when(
        () => open(any()),
      ).thenAnswer((_) async => const Success(CashfreeCheckoutSucceeded()));
      when(() => get('dsh_1')).thenAnswer(
        (_) async =>
            Success(order(state: CashfreeOrderState.credited, credited: 54000)),
      );
      final b = await loaded();
      final statuses = <PurchaseStatus>[];
      final sub = b.stream.listen((s) => statuses.add(s.status));
      b.add(const PurchaseCashfreeRequested('dia_1199'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.completed,
      );
      expect(
        statuses,
        containsAllInOrder([
          PurchaseStatus.creatingOrder,
          PurchaseStatus.inCashfree,
          PurchaseStatus.confirming,
        ]),
      );
      expect(s.result!.outcome, PaymentOutcome.success);
      expect(s.result!.diamondsCredited, 54000);
      expect(s.result!.rail, PaymentRail.cashfree);
      verify(() => get('dsh_1')).called(1);
      await sub.cancel();
      await b.close();
    });

    test('SDK failure and server failed → failure with SDK reason', () async {
      when(() => create(any())).thenAnswer((_) async => Success(order()));
      when(() => open(any())).thenAnswer(
        (_) async => const Success(CashfreeCheckoutFailed('payment_declined')),
      );
      when(() => get('dsh_1')).thenAnswer(
        (_) async => Success(order(state: CashfreeOrderState.failed)),
      );
      final b = await loaded();
      b.add(const PurchaseCashfreeRequested('dia_1199'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.completed,
      );
      expect(s.result!.outcome, PaymentOutcome.failed);
      expect(s.result!.failureCode, 'payment_declined');
      await b.close();
    });

    test('dismissed, server never saw a payment → cancelled', () async {
      when(() => create(any())).thenAnswer((_) async => Success(order()));
      when(
        () => open(any()),
      ).thenAnswer((_) async => const Success(CashfreeCheckoutDismissed()));
      when(() => get('dsh_1')).thenAnswer((_) async => Success(order()));
      final b = await loaded();
      b.add(const PurchaseCashfreeRequested('dia_1199'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.completed,
      );
      expect(s.result!.outcome, PaymentOutcome.failed);
      expect(s.result!.failureCode, 'payment_cancelled');
      await b.close();
    });

    test(
      'dismissed then pending then credited by polling with backoff',
      () async {
        when(() => create(any())).thenAnswer((_) async => Success(order()));
        when(
          () => open(any()),
        ).thenAnswer((_) async => const Success(CashfreeCheckoutDismissed()));
        final answers = [
          order(state: CashfreeOrderState.pending),
          order(state: CashfreeOrderState.pending),
          order(state: CashfreeOrderState.credited, credited: 54000),
        ];
        when(
          () => get('dsh_1'),
        ).thenAnswer((_) async => Success(answers.removeAt(0)));
        final b = await loaded();
        b.add(const PurchaseCashfreeRequested('dia_1199'));
        final s = await b.stream.firstWhere(
          (s) => s.status == PurchaseStatus.completed,
        );
        expect(s.result!.outcome, PaymentOutcome.success);
        expect(s.result!.diamondsCredited, 54000);
        expect(sleeps, const [Duration(seconds: 2), Duration(seconds: 3)]);
        await b.close();
      },
    );

    test('still pending after the ~60 s budget → pending result', () async {
      when(() => create(any())).thenAnswer((_) async => Success(order()));
      when(
        () => open(any()),
      ).thenAnswer((_) async => const Success(CashfreeCheckoutSucceeded()));
      when(() => get('dsh_1')).thenAnswer(
        (_) async => Success(order(state: CashfreeOrderState.pending)),
      );
      final b = await loaded();
      b.add(const PurchaseCashfreeRequested('dia_1199'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.completed,
      );
      expect(s.result!.outcome, PaymentOutcome.pending);
      expect(s.result!.orderId, 'dsh_1');
      final total = sleeps.fold(Duration.zero, (a, d) => a + d);
      expect(total, greaterThanOrEqualTo(const Duration(seconds: 60)));
      expect(total, lessThan(const Duration(seconds: 75)));
      await b.close();
    });

    test(
      'order creation retry reuses the key; a new order gets a new key',
      () async {
        final keys = <String>[];
        var calls = 0;
        when(() => create(any())).thenAnswer((inv) async {
          keys.add((inv.positionalArguments.first as CreateInput).key.value);
          return calls++ == 0 ? const Err(NetworkFailure()) : Success(order());
        });
        when(
          () => open(any()),
        ).thenAnswer((_) async => const Success(CashfreeCheckoutDismissed()));
        when(() => get('dsh_1')).thenAnswer((_) async => Success(order()));
        final b = await loaded();
        b.add(const PurchaseCashfreeRequested('dia_1199'));
        await b.stream.firstWhere((s) => s.status == PurchaseStatus.failed);
        b.add(const PurchaseCashfreeRequested('dia_1199'));
        await b.stream.firstWhere((s) => s.status == PurchaseStatus.completed);
        b.add(const PurchaseCashfreeRequested('dia_1199'));
        await b.stream.firstWhere(
          (s) => s.status == PurchaseStatus.creatingOrder,
        );
        await b.stream.firstWhere((s) => s.status == PurchaseStatus.completed);
        expect(keys, hasLength(3));
        expect(keys[0], keys[1]);
        expect(keys[2], isNot(keys[1]));
        await b.close();
      },
    );

    test('rail disabled: no order is created', () async {
      when(
        () => rails(any()),
      ).thenAnswer((_) async => const Success({PaymentRail.googlePlay}));
      final b = await loaded();
      b.add(const PurchaseCashfreeRequested('dia_1199'));
      final s = await b.stream.firstWhere(
        (s) => s.status == PurchaseStatus.failed,
      );
      expect(s.failure!.code, 'rail_disabled');
      verifyNever(() => create(any()));
      await b.close();
    });
  });

  group('PaymentResultCubit', () {
    test('deep link fetches the order; recheck refreshes pending', () async {
      var n = 0;
      when(() => get('dsh_1')).thenAnswer(
        (_) async => Success(
          n++ == 0
              ? order(state: CashfreeOrderState.pending)
              : order(state: CashfreeOrderState.credited, credited: 54000),
        ),
      );
      final c = PaymentResultCubit(get, orderId: 'dsh_1');
      await c.load();
      expect(
        (c.state as PaymentResultLoaded).result.outcome,
        PaymentOutcome.pending,
      );
      await c.recheck();
      final r = (c.state as PaymentResultLoaded).result;
      expect(r.outcome, PaymentOutcome.success);
      expect(r.diamondsCredited, 54000);
      await c.close();
    });

    test('a handed-over result is shown without fetching', () async {
      const r = PaymentResult(
        rail: PaymentRail.googlePlay,
        outcome: PaymentOutcome.success,
        orderId: 'p1',
        productId: 'dia_1199',
        diamondsCredited: 54000,
      );
      final c = PaymentResultCubit(get, orderId: 'p1', result: r);
      await c.load();
      expect(c.state, const PaymentResultLoaded(r));
      verifyNever(() => get(any()));
      await c.close();
    });
  });
}
