import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_purchases/feature_purchases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements PurchasesRepository {}

const _stuck = PurchaseNeedsVerification(
  'diamonds_4000',
  purchaseToken: 'tok-stuck',
  orderId: 'GPA.1',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_stuck);
    registerFallbackValue(IdempotencyKey.generate());
  });

  late _Repo repo;
  late StreamController<PurchaseUpdate> store;

  setUp(() {
    repo = _Repo();
    store = StreamController<PurchaseUpdate>.broadcast();
    when(repo.purchaseUpdates).thenAnswer((_) => store.stream);
    when(() => repo.verify(any(), any())).thenAnswer(
      (_) async => const Success(
        PurchaseVerification(
          purchaseId: 'p1',
          status: 'credited',
          diamondsCredited: 4000,
        ),
      ),
    );
  });
  tearDown(() => store.close());

  // Regression (2026-11-27): recovery only ran when the purchase screen was
  // open; a customer who paid while the app was killed got no Diamonds until
  // they happened to open it. The app now runs this at start and on resume.
  test('verifies every purchase the store re-delivers', () async {
    when(repo.recoverUnfinished).thenAnswer((_) async {
      store.add(_stuck);
    });
    final n = await PurchaseRecovery(repo, grace: Duration.zero).run();
    expect(n, 1);
    verify(() => repo.verify(_stuck, any())).called(1);
    expect(store.hasListener, isFalse, reason: 'stops listening afterwards');
  });

  test('nothing to recover sends nothing to the server', () async {
    when(repo.recoverUnfinished).thenAnswer((_) async {});
    expect(await PurchaseRecovery(repo, grace: Duration.zero).run(), 0);
    verifyNever(() => repo.verify(any(), any()));
  });

  test('overlapping runs share one pass', () async {
    final release = Completer<void>();
    when(repo.recoverUnfinished).thenAnswer((_) => release.future);
    final r = PurchaseRecovery(repo, grace: Duration.zero);
    final a = r.run();
    final b = r.run();
    release.complete();
    await Future.wait([a, b]);
    verify(repo.recoverUnfinished).called(1);
    // A later run is a new pass.
    when(repo.recoverUnfinished).thenAnswer((_) async {});
    await r.run();
    verify(repo.recoverUnfinished).called(1);
  });
}
