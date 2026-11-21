import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_purchases/feature_purchases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Load extends Mock implements LoadDiamondPackages {}

class _Start extends Mock implements StartPurchase {}

class _Watch extends Mock implements WatchPurchaseUpdates {}

class _Verify extends Mock implements VerifyPurchase {}

void main() {
  late _Load load;
  late _Start start;
  late _Watch watch;
  late _Verify verify;
  const purchase = PurchaseNeedsVerification(
    'dia_1199',
    purchaseToken: 'tok-1',
    orderId: 'GPA.1',
  );

  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue((purchase: purchase, key: IdempotencyKey.generate()));
  });
  setUp(() {
    load = _Load();
    start = _Start();
    watch = _Watch();
    verify = _Verify();
    when(() => watch(any())).thenAnswer((_) => const Stream.empty());
  });

  blocTest<PurchaseBloc, PurchaseState>(
    'a Play success is verified on the server and the server result is shown',
    setUp: () => when(() => verify(any())).thenAnswer(
      (_) async => const Success(
        PurchaseVerification(
          purchaseId: 'p1',
          status: 'credited',
          diamondsCredited: 54000,
        ),
      ),
    ),
    build: () => PurchaseBloc(load, start, watch, verify),
    act: (b) => b.add(const PurchaseStoreUpdated(purchase)),
    expect: () => const [
      PurchaseState(status: PurchaseStatus.verifying),
      PurchaseState(
        status: PurchaseStatus.completed,
        lastVerification: PurchaseVerification(
          purchaseId: 'p1',
          status: 'credited',
          diamondsCredited: 54000,
        ),
      ),
    ],
  );

  test('retrying the same purchase token reuses the idempotency key', () async {
    final keys = <String>[];
    when(() => verify(any())).thenAnswer((inv) async {
      final input =
          inv.positionalArguments.first
              as ({PurchaseNeedsVerification purchase, IdempotencyKey key});
      keys.add(input.key.value);
      return const Err(NetworkFailure());
    });
    final bloc = PurchaseBloc(load, start, watch, verify)
      ..add(const PurchaseStoreUpdated(purchase))
      ..add(const PurchaseStoreUpdated(purchase));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(keys.length, 2);
    expect(keys.toSet().length, 1);
    await bloc.close();
  });
}
