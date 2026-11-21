import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetMyProfile extends Mock implements GetMyProfile {}

void main() {
  late _MockGetMyProfile useCase;

  setUpAll(() => registerFallbackValue(const NoInput()));
  setUp(() => useCase = _MockGetMyProfile());

  blocTest<MyProfileCubit, MyProfileState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<Profile>(NetworkFailure())),
    build: () => MyProfileCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <MyProfileState>[
      MyProfileStateLoading(),
      MyProfileStateFailed(NetworkFailure()),
    ],
  );
}
