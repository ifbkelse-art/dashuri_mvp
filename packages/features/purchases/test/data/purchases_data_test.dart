import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_purchases/feature_purchases.dart' hide PurchaseStatus;
import 'package:feature_purchases/src/data/datasources/play_store_billing.dart';
import 'package:feature_purchases/src/data/datasources/purchases_remote_data_source.dart';
import 'package:feature_purchases/src/data/datasources/sha256.dart';
import 'package:feature_purchases/src/data/models/purchases_json.dart';
import 'package:feature_purchases/src/data/repositories/purchases_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';

class _Remote extends Mock implements PurchasesRemoteDataSource {}

class _Store extends Mock implements StoreBilling {}

class _Cashfree extends Mock implements CashfreeCheckout {}

class _Iap extends Mock implements InAppPurchase {}

class _Session extends Mock implements SessionGateway {}

class _Details extends Mock implements PurchaseDetails {}

const purchase = PurchaseNeedsVerification(
  'dia_1199',
  purchaseToken: 'tok',
  orderId: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(purchase);
    registerFallbackValue(IdempotencyKey.generate());
    registerFallbackValue(
      PurchaseParam(
        productDetails: ProductDetails(
          id: 'x',
          title: '',
          description: '',
          price: '',
          rawPrice: 0,
          currencyCode: 'INR',
        ),
      ),
    );
    registerFallbackValue(_Details());
  });

  test('sha256Hex matches FIPS test vectors', () {
    expect(
      sha256Hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256Hex(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
  });

  test('maps the catalogue with rails, prices and badges', () {
    final c = packageCatalogueFromJson({
      'items': [
        {
          'product_id': 'dia_1199',
          'diamonds': 54000,
          'price_paise': 119900,
          'label': 'Popular',
          'badge': 'Most popular',
          'provisional': true,
        },
      ],
      'rails': ['google_play', 'cashfree', 'future_rail'],
      'approx_paise_per_diamond_milli': 2220,
    });
    expect(c.packages.single, popular);
    expect(c.rails, bothRails);
    expect(c.approxPaisePerDiamondMilli, 2220);
    final old = packageCatalogueFromJson({
      'items': [
        {'product_id': 'a', 'diamonds': 1},
      ],
    });
    expect(old.rails, {PaymentRail.googlePlay});
    expect(old.packages.single.pricePaise, isNull);
  });

  test('maps CashfreeOrder', () {
    final o = cashfreeOrderFromJson({
      'order_id': 'dsh_1',
      'product_id': 'dia_1199',
      'amount_paise': 119900,
      'diamonds': 54000,
      'payment_session_id': 'sess_1',
      'environment': 'sandbox',
      'state': 'created',
      'diamonds_credited': 0,
    });
    expect(o, order());
    expect(CashfreeOrderState.fromWire('weird'), CashfreeOrderState.pending);
  });

  group('PurchasesRepositoryImpl', () {
    late _Remote remote;
    late _Store store;
    late PurchasesRepositoryImpl repo;

    setUp(() {
      remote = _Remote();
      store = _Store();
      repo = PurchasesRepositoryImpl(
        remote,
        store,
        _Cashfree(),
        cashfreeEnabled: true,
      );
      when(
        () => store.complete(any()),
      ).thenAnswer((_) async => const Success(null));
    });

    for (final (status, completes) in [
      ('credited', true),
      ('rejected', true),
      ('pending', false),
    ]) {
      test(
        'verify $status ${completes ? 'completes' : 'does not complete'} with Play',
        () async {
          when(() => remote.verifyGooglePlay(any(), any())).thenAnswer(
            (_) async => Success(
              PurchaseVerification(
                purchaseId: 'p',
                status: status,
                diamondsCredited: 0,
              ),
            ),
          );
          await repo.verify(purchase, IdempotencyKey.generate());
          if (completes) {
            verify(() => store.complete('tok')).called(1);
          } else {
            verifyNever(() => store.complete(any()));
          }
        },
      );
    }

    test('verify failure never completes', () async {
      when(
        () => remote.verifyGooglePlay(any(), any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      await repo.verify(purchase, IdempotencyKey.generate());
      verifyNever(() => store.complete(any()));
    });

    test('two verifies of the same token at once make one request', () async {
      final gate = Completer<Result<PurchaseVerification>>();
      when(
        () => remote.verifyGooglePlay(any(), any()),
      ).thenAnswer((_) => gate.future);
      final a = repo.verify(purchase, IdempotencyKey.generate());
      final b = repo.verify(purchase, IdempotencyKey.generate());
      gate.complete(
        const Success(
          PurchaseVerification(
            purchaseId: 'p',
            status: 'credited',
            diamondsCredited: 4000,
          ),
        ),
      );
      final results = await Future.wait([a, b]);
      verify(() => remote.verifyGooglePlay(any(), any())).called(1);
      verify(() => store.complete('tok')).called(1);
      expect(results[0], isA<Success<PurchaseVerification>>());
      expect(results[1], isA<Success<PurchaseVerification>>());
    });

    test('a later verify of the same token is sent again', () async {
      when(() => remote.verifyGooglePlay(any(), any())).thenAnswer(
        (_) async => const Err(NetworkFailure()),
      );
      await repo.verify(purchase, IdempotencyKey.generate());
      await repo.verify(purchase, IdempotencyKey.generate());
      verify(() => remote.verifyGooglePlay(any(), any())).called(2);
    });

    test('loadPackages merges Play prices and the balance', () async {
      when(() => remote.catalogue()).thenAnswer(
        (_) async => const Success(
          PackageCatalogue(packages: [popular], rails: bothRails),
        ),
      );
      when(
        () => remote.availableDiamonds(),
      ).thenAnswer((_) async => const Success(12480));
      when(() => store.isAvailable()).thenAnswer((_) async => true);
      when(
        () => store.queryPrices(any()),
      ).thenAnswer((_) async => const Success({'dia_1199': '₹1,199.00'}));
      final c = (await repo.loadPackages() as Success<PackageCatalogue>).value;
      expect(c.packages.single.storePrice, '₹1,199.00');
      expect(c.currentBalance, 12480);
    });

    test('clientRails reflects Play availability and the app flag', () async {
      when(() => store.isAvailable()).thenAnswer((_) async => false);
      expect(await repo.clientRails(), {PaymentRail.cashfree});
      final off = PurchasesRepositoryImpl(
        remote,
        store,
        _Cashfree(),
        cashfreeEnabled: false,
      );
      when(() => store.isAvailable()).thenAnswer((_) async => true);
      expect(await off.clientRails(), {PaymentRail.googlePlay});
    });
  });

  group('PlayStoreBilling', () {
    late _Iap iap;
    late _Session session;
    late PlayStoreBilling billing;
    late StreamController<List<PurchaseDetails>> stream;
    final product = ProductDetails(
      id: 'dia_1199',
      title: 'Popular',
      description: '',
      price: '₹1,199.00',
      rawPrice: 1199,
      currencyCode: 'INR',
    );

    setUp(() {
      iap = _Iap();
      session = _Session();
      stream = StreamController<List<PurchaseDetails>>.broadcast();
      billing = PlayStoreBilling(
        session: session,
        iap: iap,
        isAndroid: () => true,
      );
      when(() => iap.isAvailable()).thenAnswer((_) async => true);
      when(() => iap.purchaseStream).thenAnswer((_) => stream.stream);
      when(() => iap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: const [],
        ),
      );
      when(() => session.currentSession).thenReturn(
        AuthSession(userId: 'user-1', expiresAt: DateTime.utc(2030)),
      );
    });
    tearDown(() => stream.close());

    test('not on Android → unavailable, no plugin calls', () async {
      final b = PlayStoreBilling(
        session: session,
        iap: iap,
        isAndroid: () => false,
      );
      expect(await b.isAvailable(), isFalse);
      expect(await b.queryPrices({'a'}), isA<Err<Map<String, String>>>());
      verifyNever(() => iap.isAvailable());
    });

    test('buyConsumable with hashed user id and autoConsume off', () async {
      when(
        () => iap.buyConsumable(
          purchaseParam: any(named: 'purchaseParam'),
          autoConsume: any(named: 'autoConsume'),
        ),
      ).thenAnswer((_) async => true);
      final r = await billing.launchPurchase('dia_1199');
      expect(r, isA<Success<void>>());
      final captured = verify(
        () => iap.buyConsumable(
          purchaseParam: captureAny(named: 'purchaseParam'),
          autoConsume: false,
        ),
      ).captured;
      final param = captured.single as PurchaseParam;
      expect(param.productDetails.id, 'dia_1199');
      expect(param.applicationUserName, sha256Hex('user-1'));
    });

    test('unknown product fails without opening Play', () async {
      when(() => iap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: const [],
          notFoundIDs: const ['nope'],
        ),
      );
      final r = await billing.launchPurchase('nope');
      expect((r as Err<void>).failure.code, 'product_not_found');
    });

    test('maps purchase updates and completes only on request', () async {
      final d = _Details();
      when(() => d.status).thenReturn(PurchaseStatus.purchased);
      when(() => d.productID).thenReturn('dia_1199');
      when(() => d.purchaseID).thenReturn('GPA.1');
      when(() => d.pendingCompletePurchase).thenReturn(true);
      when(() => d.verificationData).thenReturn(
        PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'tok-9',
          source: 'google_play',
        ),
      );
      when(() => iap.completePurchase(any())).thenAnswer((_) async {});
      final updates = <PurchaseUpdate>[];
      final sub = billing.updates().listen(updates.add);
      stream.add([d]);
      await Future<void>.delayed(Duration.zero);
      expect(
        updates.single,
        const PurchaseNeedsVerification(
          'dia_1199',
          purchaseToken: 'tok-9',
          orderId: 'GPA.1',
        ),
      );
      verifyNever(() => iap.completePurchase(any()));
      await billing.complete('tok-9');
      verify(() => iap.completePurchase(d)).called(1);
      await sub.cancel();
    });
  });
}
