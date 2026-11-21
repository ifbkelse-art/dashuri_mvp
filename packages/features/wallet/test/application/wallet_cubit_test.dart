import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletSummary extends Mock implements GetWalletSummary {}

void main() {
  late _MockGetWalletSummary useCase;

  setUpAll(() => registerFallbackValue(const NoInput()));
  setUp(() => useCase = _MockGetWalletSummary());

  blocTest<WalletCubit, WalletState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<WalletSummary>(NetworkFailure())),
    build: () => WalletCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <WalletState>[
      WalletStateLoading(),
      WalletStateFailed(NetworkFailure()),
    ],
  );
}
