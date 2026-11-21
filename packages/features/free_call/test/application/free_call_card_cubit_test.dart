import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_free_call/feature_free_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetFreeCallCard extends Mock implements GetFreeCallCard {}

void main() {
  late _MockGetFreeCallCard useCase;

  setUpAll(() => registerFallbackValue(const NoInput()));
  setUp(() => useCase = _MockGetFreeCallCard());

  blocTest<FreeCallCardCubit, FreeCallCardState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<FreeCallCard>(NetworkFailure())),
    build: () => FreeCallCardCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <FreeCallCardState>[
      FreeCallCardStateLoading(),
      FreeCallCardStateFailed(NetworkFailure()),
    ],
  );
}
