import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetConsents extends Mock implements GetConsents {}

void main() {
  late _MockGetConsents useCase;

  setUpAll(() => registerFallbackValue(const NoInput()));
  setUp(() => useCase = _MockGetConsents());

  blocTest<SettingsCubit, SettingsState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<ConsentState>(NetworkFailure())),
    build: () => SettingsCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <SettingsState>[
      SettingsStateLoading(),
      SettingsStateFailed(NetworkFailure()),
    ],
  );
}
