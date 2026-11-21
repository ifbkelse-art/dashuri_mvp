import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_safety/feature_safety.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockListBlockedUsers extends Mock implements ListBlockedUsers {}

void main() {
  late _MockListBlockedUsers useCase;

  setUpAll(() => registerFallbackValue(const PageRequest()));
  setUp(() => useCase = _MockListBlockedUsers());

  blocTest<BlockedUsersCubit, BlockedUsersState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<Page<BlockedUser>>(NetworkFailure())),
    build: () => BlockedUsersCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <BlockedUsersState>[
      BlockedUsersStateLoading(),
      BlockedUsersStateFailed(NetworkFailure()),
    ],
  );
}
